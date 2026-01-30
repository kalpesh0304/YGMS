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
      go_alv_grid     TYPE REF TO cl_gui_alv_grid,
      go_container    TYPE REF TO cl_gui_docking_container,
      gt_fieldcat     TYPE lvc_t_fcat,
      gs_layout       TYPE lvc_s_layo,
      gv_edit_mode    TYPE abap_bool VALUE abap_false,
      ok_code         TYPE sy-ucomm.

*----------------------------------------------------------------------*
* Local Class for ALV Event Handling
*----------------------------------------------------------------------*
CLASS lcl_alv_handler DEFINITION.
  PUBLIC SECTION.
    METHODS:
      on_toolbar FOR EVENT toolbar OF cl_gui_alv_grid
        IMPORTING e_object e_interactive,
      on_user_command FOR EVENT user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm,
      on_data_changed FOR EVENT data_changed OF cl_gui_alv_grid
        IMPORTING er_data_changed e_onf4 e_onf4_before e_onf4_after e_ucomm.
ENDCLASS.

CLASS lcl_alv_handler IMPLEMENTATION.
  METHOD on_toolbar.
    DATA: ls_button TYPE stb_button.

    " Add separator
    CLEAR ls_button.
    ls_button-butn_type = 3.  " Separator
    APPEND ls_button TO e_object->mt_toolbar.

    " Allocate button
    CLEAR ls_button.
    ls_button-function  = 'ALLOCATE'.
    ls_button-icon      = icon_calculation.
    ls_button-quickinfo = 'Execute state-wise allocation'.
    ls_button-text      = 'Allocate'.
    APPEND ls_button TO e_object->mt_toolbar.

    " Validate button
    CLEAR ls_button.
    ls_button-function  = 'VALIDATE'.
    ls_button-icon      = icon_check.
    ls_button-quickinfo = 'Validate allocation data'.
    ls_button-text      = 'Validate'.
    APPEND ls_button TO e_object->mt_toolbar.

    " Edit button
    CLEAR ls_button.
    ls_button-function  = 'EDIT'.
    ls_button-icon      = icon_change.
    ls_button-quickinfo = 'Toggle edit mode'.
    ls_button-text      = 'Edit'.
    APPEND ls_button TO e_object->mt_toolbar.

    " Save button
    CLEAR ls_button.
    ls_button-function  = 'SAVE'.
    ls_button-icon      = icon_system_save.
    ls_button-quickinfo = 'Save allocation data'.
    ls_button-text      = 'Save'.
    APPEND ls_button TO e_object->mt_toolbar.

    " Reset button
    CLEAR ls_button.
    ls_button-function  = 'RESET'.
    ls_button-icon      = icon_refresh.
    ls_button-quickinfo = 'Reset allocation data'.
    ls_button-text      = 'Reset'.
    APPEND ls_button TO e_object->mt_toolbar.

    " Send button
    CLEAR ls_button.
    ls_button-function  = 'SEND'.
    ls_button-icon      = icon_mail.
    ls_button-quickinfo = 'Send data to ONGC'.
    ls_button-text      = 'Send'.
    APPEND ls_button TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD on_user_command.
    CASE e_ucomm.
      WHEN 'ALLOCATE'.
        PERFORM action_allocate.
      WHEN 'VALIDATE'.
        PERFORM action_validate.
      WHEN 'EDIT'.
        PERFORM action_edit.
      WHEN 'SAVE'.
        PERFORM action_save.
      WHEN 'RESET'.
        PERFORM action_reset.
      WHEN 'SEND'.
        PERFORM action_send.
    ENDCASE.
  ENDMETHOD.

  METHOD on_data_changed.
    " Data has been changed in the grid - changes are automatically
    " reflected in gt_allocation since it's passed by reference
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

    ls_allocation-location_id   = ls_excel-location_id.
    ls_allocation-material      = ls_excel-material.
    ls_allocation-state         = ls_excel-state.
    ls_allocation-state_code    = ls_excel-state_code.
    ls_allocation-total_mbg     = ls_excel-qty_mbg.
    ls_allocation-total_scm     = ls_excel-qty_scm.
    ls_allocation-avg_gcv       = ls_excel-gcv.
    ls_allocation-avg_ncv       = ls_excel-ncv.
    ls_allocation-fnt_start     = s_date-low.
    ls_allocation-fnt_end       = s_date-high.

    APPEND ls_allocation TO gt_allocation.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form BUILD_FIELDCAT
*& Build field catalog for ALV grid
*&---------------------------------------------------------------------*
FORM build_fieldcat.
  DATA: ls_fcat    TYPE lvc_s_fcat,
        lv_day     TYPE i,
        lv_colname TYPE lvc_fname,
        lv_date    TYPE datum,
        lv_datetxt TYPE string.

  CLEAR gt_fieldcat.

  " Exclude checkbox
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'EXCLUDE'.
  ls_fcat-coltext   = 'Exclude'.
  ls_fcat-checkbox  = abap_true.
  ls_fcat-edit      = abap_true.
  ls_fcat-outputlen = 8.
  APPEND ls_fcat TO gt_fieldcat.

  " State Code
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'STATE_CODE'.
  ls_fcat-coltext   = 'State Code'.
  ls_fcat-outputlen = 10.
  APPEND ls_fcat TO gt_fieldcat.

  " State
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'STATE'.
  ls_fcat-coltext   = 'State'.
  ls_fcat-outputlen = 20.
  APPEND ls_fcat TO gt_fieldcat.

  " Location ID
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'LOCATION_ID'.
  ls_fcat-coltext   = 'Location ID'.
  ls_fcat-outputlen = 12.
  APPEND ls_fcat TO gt_fieldcat.

  " Material
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'MATERIAL'.
  ls_fcat-coltext   = 'Material'.
  ls_fcat-outputlen = 18.
  APPEND ls_fcat TO gt_fieldcat.

  " Total MBG
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'TOTAL_MBG'.
  ls_fcat-coltext   = 'Total MBG'.
  ls_fcat-outputlen = 15.
  ls_fcat-do_sum    = abap_true.
  APPEND ls_fcat TO gt_fieldcat.

  " Total SCM
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'TOTAL_SCM'.
  ls_fcat-coltext   = 'Total Sm3'.
  ls_fcat-outputlen = 15.
  ls_fcat-do_sum    = abap_true.
  APPEND ls_fcat TO gt_fieldcat.

  " Daily columns (DAY01 to DAY15) - Editable
  lv_date = s_date-low.
  DO 15 TIMES.
    lv_day = sy-index.
    lv_colname = |DAY{ lv_day WIDTH = 2 ALIGN = RIGHT PAD = '0' }|.
    lv_datetxt = |{ lv_date+6(2) }-{ lv_date+4(2) }|.

    CLEAR ls_fcat.
    ls_fcat-fieldname = lv_colname.
    ls_fcat-coltext   = lv_datetxt.
    ls_fcat-outputlen = 12.
    ls_fcat-edit      = abap_true.  " Make daily columns editable
    ls_fcat-do_sum    = abap_true.
    APPEND ls_fcat TO gt_fieldcat.

    lv_date = lv_date + 1.
  ENDDO.

  " Average GCV - Editable
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'AVG_GCV'.
  ls_fcat-coltext   = 'Avg GCV'.
  ls_fcat-outputlen = 12.
  ls_fcat-edit      = abap_true.
  APPEND ls_fcat TO gt_fieldcat.

  " Average NCV - Editable
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'AVG_NCV'.
  ls_fcat-coltext   = 'Avg NCV'.
  ls_fcat-outputlen = 12.
  ls_fcat-edit      = abap_true.
  APPEND ls_fcat TO gt_fieldcat.

  " Hidden fields
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'FNT_START'.
  ls_fcat-coltext   = 'FNT Start'.
  ls_fcat-no_out    = abap_true.
  APPEND ls_fcat TO gt_fieldcat.

  CLEAR ls_fcat.
  ls_fcat-fieldname = 'FNT_END'.
  ls_fcat-coltext   = 'FNT End'.
  ls_fcat-no_out    = abap_true.
  APPEND ls_fcat TO gt_fieldcat.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form DISPLAY_ALV
*&---------------------------------------------------------------------*
FORM display_alv.
  " Build field catalog
  PERFORM build_fieldcat.

  " Set layout
  gs_layout-zebra      = abap_true.
  gs_layout-cwidth_opt = abap_true.
  gs_layout-sel_mode   = 'A'.  " Multiple row selection

  " Create docking container
  IF go_container IS INITIAL.
    CREATE OBJECT go_container
      EXPORTING
        side                    = cl_gui_docking_container=>dock_at_bottom
        ratio                   = 95
      EXCEPTIONS
        cntl_error              = 1
        cntl_system_error       = 2
        create_error            = 3
        lifetime_error          = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                  = 6.

    IF sy-subrc <> 0.
      MESSAGE 'Error creating container' TYPE 'E'.
      RETURN.
    ENDIF.
  ENDIF.

  " Create ALV grid
  IF go_alv_grid IS INITIAL.
    CREATE OBJECT go_alv_grid
      EXPORTING
        i_parent = go_container
      EXCEPTIONS
        OTHERS   = 1.

    IF sy-subrc <> 0.
      MESSAGE 'Error creating ALV grid' TYPE 'E'.
      RETURN.
    ENDIF.

    " Create and set event handler
    CREATE OBJECT go_alv_handler.
    SET HANDLER go_alv_handler->on_toolbar FOR go_alv_grid.
    SET HANDLER go_alv_handler->on_user_command FOR go_alv_grid.
    SET HANDLER go_alv_handler->on_data_changed FOR go_alv_grid.

    " Register edit events
    CALL METHOD go_alv_grid->register_edit_event
      EXPORTING
        i_event_id = cl_gui_alv_grid=>mc_evt_modified
      EXCEPTIONS
        error      = 1
        OTHERS     = 2.

    " Display ALV
    CALL METHOD go_alv_grid->set_table_for_first_display
      EXPORTING
        i_structure_name = 'YGMS_S_ALLOCATION'
        is_layout        = gs_layout
        i_save           = 'A'
      CHANGING
        it_outtab        = gt_allocation
        it_fieldcatalog  = gt_fieldcat
      EXCEPTIONS
        OTHERS           = 1.

    IF sy-subrc <> 0.
      MESSAGE 'Error displaying ALV' TYPE 'E'.
      RETURN.
    ENDIF.
  ELSE.
    " Refresh existing ALV
    CALL METHOD go_alv_grid->refresh_table_display
      EXCEPTIONS
        finished = 1
        OTHERS   = 2.
  ENDIF.

  " Write dummy output to trigger screen
  WRITE: / 'CST Purchase Data Allocation'.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form ACTION_SAVE
*&---------------------------------------------------------------------*
FORM action_save.
  DATA: lv_answer TYPE c.

  " Check for pending changes
  IF go_alv_grid IS NOT INITIAL.
    CALL METHOD go_alv_grid->check_changed_data.
  ENDIF.

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

  " Check for pending changes
  IF go_alv_grid IS NOT INITIAL.
    CALL METHOD go_alv_grid->check_changed_data.
  ENDIF.

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
            iv_email_address = p_email
          IMPORTING
            et_messages      = gt_messages
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
      IF go_alv_grid IS NOT INITIAL.
        CALL METHOD go_alv_grid->refresh_table_display.
      ENDIF.
      MESSAGE |Allocation completed. { lines( gt_allocation ) } records| TYPE 'S'.
    CATCH ygms_cx_cst_error INTO DATA(lx_error).
      MESSAGE lx_error TYPE 'E'.
  ENDTRY.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form ACTION_VALIDATE
*&---------------------------------------------------------------------*
FORM action_validate.
  DATA: lv_valid TYPE abap_bool.

  " Check for pending changes first
  IF go_alv_grid IS NOT INITIAL.
    CALL METHOD go_alv_grid->check_changed_data.
  ENDIF.

  TRY.
      " Validate allocation data
      lv_valid = go_controller->validate_allocation_data( gt_allocation ).

      IF lv_valid = abap_true.
        MESSAGE 'Validation successful - No errors found' TYPE 'S'.
      ELSE.
        MESSAGE 'Validation failed - Please check the data' TYPE 'E'.
      ENDIF.
    CATCH ygms_cx_cst_error INTO DATA(lx_error).
      MESSAGE lx_error TYPE 'E'.
  ENDTRY.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form ACTION_EDIT
*&---------------------------------------------------------------------*
FORM action_edit.
  DATA: ls_layout TYPE lvc_s_layo.

  IF go_alv_grid IS INITIAL.
    MESSAGE 'ALV grid not initialized' TYPE 'E'.
    RETURN.
  ENDIF.

  " Toggle edit mode
  IF gv_edit_mode = abap_false.
    gv_edit_mode = abap_true.

    " Enable edit mode
    CALL METHOD go_alv_grid->set_ready_for_input
      EXPORTING
        i_ready_for_input = 1.

    MESSAGE 'Edit mode enabled. Modify values and click Save.' TYPE 'S'.
  ELSE.
    gv_edit_mode = abap_false.

    " Check for pending changes before disabling
    CALL METHOD go_alv_grid->check_changed_data.

    " Disable edit mode
    CALL METHOD go_alv_grid->set_ready_for_input
      EXPORTING
        i_ready_for_input = 0.

    MESSAGE 'Edit mode disabled.' TYPE 'S'.
  ENDIF.
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
        IF go_alv_grid IS NOT INITIAL.
          CALL METHOD go_alv_grid->refresh_table_display.
        ENDIF.
        MESSAGE 'Data reset to original values' TYPE 'S'.
      CATCH ygms_cx_cst_error INTO DATA(lx_error).
        MESSAGE lx_error TYPE 'E'.
    ENDTRY.
  ENDIF.
ENDFORM.
