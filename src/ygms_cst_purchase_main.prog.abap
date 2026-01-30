*&---------------------------------------------------------------------*
*& Report YGMS_CST_PURCHASE_MAIN
*& Description: ONGC CST Purchase Data Sharing - Main Program
*&---------------------------------------------------------------------*
REPORT ygms_cst_purchase_main.

INCLUDE <icon>.

*----------------------------------------------------------------------*
* Type definitions for Excel upload
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_excel_data,
         gas_day      TYPE datum,
         location_id  TYPE char10,
         material     TYPE matnr,
         state        TYPE char30,
         state_code   TYPE char2,
         qty_mbg      TYPE p LENGTH 15 DECIMALS 3,
         qty_scm      TYPE p LENGTH 15 DECIMALS 3,
         gcv          TYPE p LENGTH 10 DECIMALS 3,
         ncv          TYPE p LENGTH 10 DECIMALS 3,
         tax_type     TYPE char3,
       END OF ty_excel_data.

*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-001.
  PARAMETERS:     p_loc    TYPE ygms_de_loc_id OBLIGATORY.
  SELECT-OPTIONS: s_date   FOR sy-datum OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE text-002.
  PARAMETERS: p_db   RADIOBUTTON GROUP rb1 DEFAULT 'X' USER-COMMAND uc1,  "From Database
              p_upld RADIOBUTTON GROUP rb1.                                "From Excel
  PARAMETERS: p_file TYPE rlgrap-filename MODIF ID upl.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE text-003.
  PARAMETERS: p_disp RADIOBUTTON GROUP rb2 DEFAULT 'X',
              p_save RADIOBUTTON GROUP rb2,
              p_send RADIOBUTTON GROUP rb2.
  PARAMETERS: p_email TYPE ad_smtpadr.
SELECTION-SCREEN END OF BLOCK b3.

*----------------------------------------------------------------------*
* Global Data
*----------------------------------------------------------------------*
DATA: go_controller   TYPE REF TO ygms_cl_cst_controller,
      gt_allocation   TYPE ygms_tt_allocation,
      gt_messages     TYPE bapiret2_t,
      gv_gail_id      TYPE ygms_de_gail_id,
      gt_excel_data   TYPE TABLE OF ty_excel_data,
      go_alv          TYPE REF TO cl_salv_table.

*----------------------------------------------------------------------*
* Local Class for ALV Event Handling
*----------------------------------------------------------------------*
CLASS lcl_alv_handler DEFINITION.
  PUBLIC SECTION.
    METHODS:
      on_user_command FOR EVENT added_function OF cl_salv_events
        IMPORTING e_salv_function.
ENDCLASS.

CLASS lcl_alv_handler IMPLEMENTATION.
  METHOD on_user_command.
    CASE e_salv_function.
      WHEN 'SAVE'.
        " Save data
        PERFORM action_save.
      WHEN 'SEND'.
        " Send to ONGC
        PERFORM action_send.
      WHEN 'DOWNLOAD'.
        " Download to Excel
        PERFORM action_download.
      WHEN 'REFRESH'.
        " Refresh data
        PERFORM action_refresh.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.

DATA: go_alv_handler TYPE REF TO lcl_alv_handler.

*----------------------------------------------------------------------*
* At Selection Screen Output
*----------------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.
  LOOP AT SCREEN.
    IF screen-group1 = 'UPL'.
      IF p_upld = abap_true.
        screen-active = 1.
      ELSE.
        screen-active = 0.
      ENDIF.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

*----------------------------------------------------------------------*
* At Selection Screen on Value Request
*----------------------------------------------------------------------*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f4_file_path.

*----------------------------------------------------------------------*
* Initialization
*----------------------------------------------------------------------*
INITIALIZATION.
  " Set default date range (current month)
  s_date-sign   = 'I'.
  s_date-option = 'BT'.
  s_date-low    = sy-datum - sy-datum+6(2) + 1.
  s_date-high   = sy-datum.
  APPEND s_date.

*----------------------------------------------------------------------*
* Start of Selection
*----------------------------------------------------------------------*
START-OF-SELECTION.
  " Create controller instance
  CREATE OBJECT go_controller.

  " Set selection parameters
  go_controller->set_selection(
    iv_location_id = p_loc
    iv_date_from   = s_date-low
    iv_date_to     = s_date-high
  ).

  TRY.
      IF p_upld = abap_true.
        " Upload from Excel
        PERFORM upload_excel.
        PERFORM convert_excel_to_allocation.
      ELSE.
        " Execute allocation from database
        go_controller->execute_allocation(
          IMPORTING
            et_allocation      = gt_allocation
            et_messages        = gt_messages
        ).
      ENDIF.

      " Process based on selected option
      CASE abap_true.
        WHEN p_disp.
          " Display only - show ALV
          PERFORM display_alv.

        WHEN p_save.
          " Save data
          go_controller->save_data(
            EXPORTING
              it_data     = gt_allocation
            IMPORTING
              ev_gail_id  = gv_gail_id
              et_messages = gt_messages
          ).
          PERFORM display_alv.

        WHEN p_send.
          " Save and send
          go_controller->save_data(
            EXPORTING
              it_data     = gt_allocation
            IMPORTING
              ev_gail_id  = gv_gail_id
              et_messages = gt_messages
          ).
          go_controller->send_data(
            EXPORTING
              iv_email_address = p_email
            IMPORTING
              et_messages      = gt_messages
          ).
          PERFORM display_alv.
      ENDCASE.

    CATCH ygms_cx_cst_error INTO DATA(lx_error).
      MESSAGE lx_error TYPE 'E'.
  ENDTRY.

*&---------------------------------------------------------------------*
*& Form F4_FILE_PATH
*& File open dialog for Excel file selection
*&---------------------------------------------------------------------*
FORM f4_file_path.
  DATA: lt_file_table TYPE filetable,
        lv_rc         TYPE i,
        lv_action     TYPE i.

  cl_gui_frontend_services=>file_open_dialog(
    EXPORTING
      window_title      = 'Select Excel File'
      default_extension = 'XLSX'
      file_filter       = 'Excel Files (*.xlsx;*.xls)|*.xlsx;*.xls|All Files (*.*)|*.*'
    CHANGING
      file_table        = lt_file_table
      rc                = lv_rc
      user_action       = lv_action
    EXCEPTIONS
      OTHERS            = 1
  ).

  IF sy-subrc = 0 AND lv_action = cl_gui_frontend_services=>action_ok.
    READ TABLE lt_file_table INTO DATA(ls_file) INDEX 1.
    IF sy-subrc = 0.
      p_file = ls_file-filename.
    ENDIF.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form UPLOAD_EXCEL
*& Upload Excel file and convert to internal table
*&---------------------------------------------------------------------*
FORM upload_excel.
  DATA: lt_raw_data TYPE truxs_t_text_data.

  IF p_file IS INITIAL.
    MESSAGE 'Please select an Excel file' TYPE 'E'.
    RETURN.
  ENDIF.

  " Upload file
  CALL FUNCTION 'TEXT_CONVERT_XLS_TO_SAP'
    EXPORTING
      i_line_header        = 'X'
      i_tab_raw_data       = lt_raw_data
      i_filename           = p_file
    TABLES
      i_tab_converted_data = gt_excel_data
    EXCEPTIONS
      conversion_failed    = 1
      OTHERS               = 2.

  IF sy-subrc <> 0.
    MESSAGE 'Error uploading Excel file' TYPE 'E'.
  ELSE.
    MESSAGE |{ lines( gt_excel_data ) } records uploaded from Excel| TYPE 'S'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form CONVERT_EXCEL_TO_ALLOCATION
*& Convert uploaded Excel data to allocation format
*&---------------------------------------------------------------------*
FORM convert_excel_to_allocation.
  DATA: ls_allocation TYPE ygms_s_allocation.

  CLEAR gt_allocation.

  LOOP AT gt_excel_data INTO DATA(ls_excel).
    CLEAR ls_allocation.

    ls_allocation-gas_day       = ls_excel-gas_day.
    ls_allocation-location_id   = ls_excel-location_id.
    ls_allocation-material      = ls_excel-material.
    ls_allocation-state         = ls_excel-state.
    ls_allocation-state_code    = ls_excel-state_code.
    ls_allocation-supply_qty_mbg = ls_excel-qty_mbg.
    ls_allocation-supply_qty_scm = ls_excel-qty_scm.
    ls_allocation-alloc_qty_mbg = ls_excel-qty_mbg.
    ls_allocation-alloc_qty_scm = ls_excel-qty_scm.
    ls_allocation-alloc_pct     = 100.
    ls_allocation-gcv           = ls_excel-gcv.
    ls_allocation-ncv           = ls_excel-ncv.
    ls_allocation-tax_type      = ls_excel-tax_type.

    APPEND ls_allocation TO gt_allocation.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form DISPLAY_ALV
*&---------------------------------------------------------------------*
FORM display_alv.
  DATA: lo_functions TYPE REF TO cl_salv_functions_list,
        lo_columns   TYPE REF TO cl_salv_columns_table,
        lo_column    TYPE REF TO cl_salv_column,
        lo_events    TYPE REF TO cl_salv_events_table.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = go_alv
        CHANGING
          t_table      = gt_allocation
      ).

      " Enable all standard functions
      lo_functions = go_alv->get_functions( ).
      lo_functions->set_all( abap_true ).

      " Add custom buttons
      TRY.
          lo_functions->add_function(
            name     = 'SAVE'
            icon     = icon_system_save
            text     = 'Save Data'
            tooltip  = 'Save allocation data to database'
            position = if_salv_c_function_position=>right_of_salv_functions
          ).
          lo_functions->add_function(
            name     = 'SEND'
            icon     = icon_mail
            text     = 'Send to ONGC'
            tooltip  = 'Save and send data to ONGC'
            position = if_salv_c_function_position=>right_of_salv_functions
          ).
          lo_functions->add_function(
            name     = 'DOWNLOAD'
            icon     = icon_export
            text     = 'Download'
            tooltip  = 'Download data to Excel'
            position = if_salv_c_function_position=>right_of_salv_functions
          ).
          lo_functions->add_function(
            name     = 'REFRESH'
            icon     = icon_refresh
            text     = 'Refresh'
            tooltip  = 'Refresh data from database'
            position = if_salv_c_function_position=>right_of_salv_functions
          ).
        CATCH cx_salv_wrong_call cx_salv_existing.
      ENDTRY.

      " Set up event handler
      CREATE OBJECT go_alv_handler.
      lo_events = go_alv->get_event( ).
      SET HANDLER go_alv_handler->on_user_command FOR lo_events.

      " Set column texts
      lo_columns = go_alv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      TRY.
          lo_column = lo_columns->get_column( 'GAS_DAY' ).
          lo_column->set_short_text( 'Gas Day' ).
          lo_column->set_medium_text( 'Gas Day' ).
          lo_column->set_long_text( 'Gas Day' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column = lo_columns->get_column( 'LOCATION_ID' ).
          lo_column->set_short_text( 'Location' ).
          lo_column->set_medium_text( 'Location ID' ).
          lo_column->set_long_text( 'Location ID' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column = lo_columns->get_column( 'STATE' ).
          lo_column->set_short_text( 'State' ).
          lo_column->set_medium_text( 'State Name' ).
          lo_column->set_long_text( 'State Name' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column = lo_columns->get_column( 'STATE_CODE' ).
          lo_column->set_short_text( 'St.Code' ).
          lo_column->set_medium_text( 'State Code' ).
          lo_column->set_long_text( 'State Code' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column = lo_columns->get_column( 'SUPPLY_QTY_MBG' ).
          lo_column->set_short_text( 'Sup MBG' ).
          lo_column->set_medium_text( 'Supply MMBTU' ).
          lo_column->set_long_text( 'Supply Quantity (MMBTU)' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column = lo_columns->get_column( 'SUPPLY_QTY_SCM' ).
          lo_column->set_short_text( 'Sup SCM' ).
          lo_column->set_medium_text( 'Supply SCM' ).
          lo_column->set_long_text( 'Supply Quantity (SCM)' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column = lo_columns->get_column( 'ALLOC_QTY_MBG' ).
          lo_column->set_short_text( 'Alloc MBG' ).
          lo_column->set_medium_text( 'Allocated MMBTU' ).
          lo_column->set_long_text( 'Allocated Quantity (MMBTU)' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column = lo_columns->get_column( 'ALLOC_QTY_SCM' ).
          lo_column->set_short_text( 'Alloc SCM' ).
          lo_column->set_medium_text( 'Allocated SCM' ).
          lo_column->set_long_text( 'Allocated Quantity (SCM)' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column = lo_columns->get_column( 'ALLOC_PCT' ).
          lo_column->set_short_text( 'Alloc %' ).
          lo_column->set_medium_text( 'Allocation %' ).
          lo_column->set_long_text( 'Allocation Percentage' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column = lo_columns->get_column( 'TAX_TYPE' ).
          lo_column->set_short_text( 'Tax' ).
          lo_column->set_medium_text( 'Tax Type' ).
          lo_column->set_long_text( 'Tax Type (CST/GST)' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      " Set ALV title
      go_alv->get_display_settings( )->set_list_header( 'CST Purchase Data Allocation' ).

      " Display
      go_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv TYPE 'E'.
  ENDTRY.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form ACTION_SAVE
*&---------------------------------------------------------------------*
FORM action_save.
  DATA: lv_answer TYPE c.

  " Confirm save
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Confirm Save'
      text_question         = 'Do you want to save the allocation data?'
      text_button_1         = 'Yes'
      text_button_2         = 'No'
      default_button        = '2'
      display_cancel_button = abap_false
    IMPORTING
      answer                = lv_answer.

  IF lv_answer = '1'.
    TRY.
        go_controller->save_data(
          EXPORTING
            it_data     = gt_allocation
          IMPORTING
            ev_gail_id  = gv_gail_id
            et_messages = gt_messages
        ).
        MESSAGE |Data saved successfully. GAIL ID: { gv_gail_id }| TYPE 'S'.
      CATCH ygms_cx_cst_error INTO DATA(lx_error).
        MESSAGE lx_error TYPE 'E'.
    ENDTRY.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form ACTION_SEND
*&---------------------------------------------------------------------*
FORM action_send.
  DATA: lv_answer TYPE c.

  " Confirm send
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Confirm Send to ONGC'
      text_question         = 'Do you want to save and send data to ONGC?'
      text_button_1         = 'Yes'
      text_button_2         = 'No'
      default_button        = '2'
      display_cancel_button = abap_false
    IMPORTING
      answer                = lv_answer.

  IF lv_answer = '1'.
    TRY.
        " First save
        go_controller->save_data(
          EXPORTING
            it_data     = gt_allocation
          IMPORTING
            ev_gail_id  = gv_gail_id
            et_messages = gt_messages
        ).

        " Then send
        go_controller->send_data(
          EXPORTING
            iv_gail_id     = gv_gail_id
            iv_email       = p_email
          IMPORTING
            et_messages    = gt_messages
        ).
        MESSAGE |Data sent to ONGC successfully. GAIL ID: { gv_gail_id }| TYPE 'S'.
      CATCH ygms_cx_cst_error INTO DATA(lx_error).
        MESSAGE lx_error TYPE 'E'.
    ENDTRY.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form ACTION_DOWNLOAD
*&---------------------------------------------------------------------*
FORM action_download.
  DATA: lv_filename TYPE string,
        lv_path     TYPE string,
        lv_fullpath TYPE string,
        lv_action   TYPE i.

  " Get save path
  cl_gui_frontend_services=>file_save_dialog(
    EXPORTING
      window_title         = 'Save Allocation Data'
      default_extension    = 'XLS'
      default_file_name    = |CST_Allocation_{ sy-datum }|
      file_filter          = 'Excel Files (*.xls)|*.xls'
    CHANGING
      filename             = lv_filename
      path                 = lv_path
      fullpath             = lv_fullpath
      user_action          = lv_action
    EXCEPTIONS
      OTHERS               = 1
  ).

  IF sy-subrc = 0 AND lv_action = cl_gui_frontend_services=>action_ok.
    " Download data
    CALL FUNCTION 'GUI_DOWNLOAD'
      EXPORTING
        filename                = lv_fullpath
        filetype                = 'ASC'
        write_field_separator   = 'X'
      TABLES
        data_tab                = gt_allocation
      EXCEPTIONS
        OTHERS                  = 1.

    IF sy-subrc = 0.
      MESSAGE 'Data downloaded successfully' TYPE 'S'.
    ELSE.
      MESSAGE 'Error downloading data' TYPE 'E'.
    ENDIF.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form ACTION_REFRESH
*&---------------------------------------------------------------------*
FORM action_refresh.
  TRY.
      " Re-execute allocation from database
      go_controller->execute_allocation(
        IMPORTING
          et_allocation = gt_allocation
          et_messages   = gt_messages
      ).

      " Refresh ALV
      go_alv->refresh( ).
      MESSAGE |Data refreshed. { lines( gt_allocation ) } records loaded| TYPE 'S'.
    CATCH ygms_cx_cst_error INTO DATA(lx_error).
      MESSAGE lx_error TYPE 'E'.
  ENDTRY.
ENDFORM.
