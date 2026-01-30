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
      WHEN 'ALLOCATE'.
        " Execute allocation
        PERFORM action_allocate.
      WHEN 'VALIDATE'.
        " Validate data
        PERFORM action_validate.
      WHEN 'EDIT'.
        " Enable edit mode
        PERFORM action_edit.
      WHEN 'SAVE'.
        " Save data
        PERFORM action_save.
      WHEN 'RESET'.
        " Reset data
        PERFORM action_reset.
      WHEN 'SEND'.
        " Send to ONGC
        PERFORM action_send.
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
        lo_events    TYPE REF TO cl_salv_events_table,
        lv_day       TYPE i,
        lv_colname   TYPE lvc_fname,
        lv_date      TYPE datum,
        lv_datetxt   TYPE string.

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

      " Add custom buttons: Allocate, Validate, Edit, Save, Reset, Send
      TRY.
          lo_functions->add_function(
            name     = 'ALLOCATE'
            icon     = icon_calculation
            text     = 'Allocate'
            tooltip  = 'Execute state-wise allocation'
            position = if_salv_c_function_position=>right_of_salv_functions
          ).
          lo_functions->add_function(
            name     = 'VALIDATE'
            icon     = icon_check
            text     = 'Validate'
            tooltip  = 'Validate allocation data'
            position = if_salv_c_function_position=>right_of_salv_functions
          ).
          lo_functions->add_function(
            name     = 'EDIT'
            icon     = icon_change
            text     = 'Edit'
            tooltip  = 'Enable edit mode'
            position = if_salv_c_function_position=>right_of_salv_functions
          ).
          lo_functions->add_function(
            name     = 'SAVE'
            icon     = icon_system_save
            text     = 'Save'
            tooltip  = 'Save allocation data'
            position = if_salv_c_function_position=>right_of_salv_functions
          ).
          lo_functions->add_function(
            name     = 'RESET'
            icon     = icon_refresh
            text     = 'Reset'
            tooltip  = 'Reset allocation data'
            position = if_salv_c_function_position=>right_of_salv_functions
          ).
          lo_functions->add_function(
            name     = 'SEND'
            icon     = icon_mail
            text     = 'Send'
            tooltip  = 'Send data to ONGC'
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

      " Exclude checkbox column
      TRY.
          lo_column = lo_columns->get_column( 'EXCLUDE' ).
          lo_column->set_short_text( 'Exclude' ).
          lo_column->set_medium_text( 'Exclude' ).
          lo_column->set_long_text( 'Exclude from Allocation' ).
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
          lo_column = lo_columns->get_column( 'STATE' ).
          lo_column->set_short_text( 'State' ).
          lo_column->set_medium_text( 'State' ).
          lo_column->set_long_text( 'State Name' ).
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
          lo_column = lo_columns->get_column( 'MATERIAL' ).
          lo_column->set_short_text( 'Material' ).
          lo_column->set_medium_text( 'Material' ).
          lo_column->set_long_text( 'Material Number' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column = lo_columns->get_column( 'TOTAL_MBG' ).
          lo_column->set_short_text( 'Total MBG' ).
          lo_column->set_medium_text( 'Total, MBG' ).
          lo_column->set_long_text( 'Total Quantity (MMBTU)' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column = lo_columns->get_column( 'TOTAL_SCM' ).
          lo_column->set_short_text( 'Total Sm3' ).
          lo_column->set_medium_text( 'Total, Sm3' ).
          lo_column->set_long_text( 'Total Quantity (Sm3)' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      " Set column texts for daily columns (DAY01 to DAY15)
      lv_date = s_date-low.  " Start date from selection
      DO 15 TIMES.
        lv_day = sy-index.
        lv_colname = |DAY{ lv_day WIDTH = 2 ALIGN = RIGHT PAD = '0' }|.
        lv_datetxt = |{ lv_date+6(2) }-{ lv_date+4(2) }-{ lv_date+0(4) }|.
        TRY.
            lo_column = lo_columns->get_column( lv_colname ).
            lo_column->set_short_text( CONV #( lv_datetxt ) ).
            lo_column->set_medium_text( CONV #( lv_datetxt ) ).
            lo_column->set_long_text( CONV #( lv_datetxt ) ).
          CATCH cx_salv_not_found.
        ENDTRY.
        lv_date = lv_date + 1.
      ENDDO.

      TRY.
          lo_column = lo_columns->get_column( 'AVG_GCV' ).
          lo_column->set_short_text( 'Avg GCV' ).
          lo_column->set_medium_text( 'Average GCV' ).
          lo_column->set_long_text( 'Average Gross Calorific Value' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column = lo_columns->get_column( 'AVG_NCV' ).
          lo_column->set_short_text( 'Avg NCV' ).
          lo_column->set_medium_text( 'Average NCV' ).
          lo_column->set_long_text( 'Average Net Calorific Value' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      " Hide internal fields
      TRY.
          lo_column = lo_columns->get_column( 'FNT_START' ).
          lo_column->set_visible( abap_false ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column = lo_columns->get_column( 'FNT_END' ).
          lo_column->set_visible( abap_false ).
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
*& Form ACTION_ALLOCATE
*&---------------------------------------------------------------------*
FORM action_allocate.
  TRY.
      " Execute state-wise allocation
      go_controller->execute_allocation(
        IMPORTING
          et_allocation = gt_allocation
          et_messages   = gt_messages
      ).

      " Refresh ALV
      go_alv->refresh( ).
      MESSAGE |Allocation completed. { lines( gt_allocation ) } records| TYPE 'S'.
    CATCH ygms_cx_cst_error INTO DATA(lx_error).
      MESSAGE lx_error TYPE 'E'.
  ENDTRY.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form ACTION_VALIDATE
*&---------------------------------------------------------------------*
FORM action_validate.
  DATA: lv_errors   TYPE i,
        lv_warnings TYPE i.

  TRY.
      " Validate allocation data
      go_controller->validate_allocation(
        EXPORTING
          it_allocation = gt_allocation
        IMPORTING
          ev_errors     = lv_errors
          ev_warnings   = lv_warnings
          et_messages   = gt_messages
      ).

      IF lv_errors > 0.
        MESSAGE |Validation failed: { lv_errors } errors, { lv_warnings } warnings| TYPE 'E'.
      ELSEIF lv_warnings > 0.
        MESSAGE |Validation passed with { lv_warnings } warnings| TYPE 'W'.
      ELSE.
        MESSAGE 'Validation successful - No errors found' TYPE 'S'.
      ENDIF.
    CATCH ygms_cx_cst_error INTO DATA(lx_error).
      MESSAGE lx_error TYPE 'E'.
  ENDTRY.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form ACTION_EDIT
*&---------------------------------------------------------------------*
FORM action_edit.
  " Enable edit mode in ALV
  " Note: For full edit functionality, cl_gui_alv_grid would be needed
  MESSAGE 'Edit mode enabled. Modify values and click Save.' TYPE 'S'.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form ACTION_RESET
*&---------------------------------------------------------------------*
FORM action_reset.
  DATA: lv_answer TYPE c.

  " Confirm reset
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = 'Confirm Reset'
      text_question         = 'Do you want to reset all allocation data?'
      text_button_1         = 'Yes'
      text_button_2         = 'No'
      default_button        = '2'
      display_cancel_button = abap_false
    IMPORTING
      answer                = lv_answer.

  IF lv_answer = '1'.
    TRY.
        " Re-load original data from database
        go_controller->execute_allocation(
          IMPORTING
            et_allocation = gt_allocation
            et_messages   = gt_messages
        ).

        " Refresh ALV
        go_alv->refresh( ).
        MESSAGE 'Data reset to original values' TYPE 'S'.
      CATCH ygms_cx_cst_error INTO DATA(lx_error).
        MESSAGE lx_error TYPE 'E'.
    ENDTRY.
  ENDIF.
ENDFORM.
