*&---------------------------------------------------------------------*
*& Report YGMS_CST_EXCEL_UPLOAD
*& Description: Excel Upload Program for CST Purchase Data
*&---------------------------------------------------------------------*
REPORT ygms_cst_excel_upload.

*----------------------------------------------------------------------*
* Type definitions for Excel upload
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_excel_raw,
         col1  TYPE char50,   "Gas Day
         col2  TYPE char50,   "Location ID
         col3  TYPE char50,   "Material
         col4  TYPE char50,   "State
         col5  TYPE char50,   "State Code
         col6  TYPE char50,   "Qty MMBTU
         col7  TYPE char50,   "Qty SCM
         col8  TYPE char50,   "GCV
         col9  TYPE char50,   "NCV
         col10 TYPE char50,   "Tax Type
       END OF ty_excel_raw.

TYPES: BEGIN OF ty_upload_data,
         gas_day      TYPE datum,
         location_id  TYPE char10,
         material     TYPE matnr,
         state        TYPE char30,
         state_code   TYPE char2,
         qty_mbg      TYPE ygms_de_qty_mbg,
         qty_scm      TYPE ygms_de_qty_scm,
         gcv          TYPE ygms_de_gcv,
         ncv          TYPE ygms_de_ncv,
         tax_type     TYPE char3,
         status       TYPE char1,      "S=Success, E=Error
         message      TYPE char100,
       END OF ty_upload_data.

*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-001.
  PARAMETERS: p_file TYPE rlgrap-filename OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE text-002.
  PARAMETERS: p_test RADIOBUTTON GROUP rb1 DEFAULT 'X',  "Test Mode
              p_save RADIOBUTTON GROUP rb1.               "Save Mode
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE text-003.
  PARAMETERS: p_templ TYPE c AS CHECKBOX.  "Download Template
SELECTION-SCREEN END OF BLOCK b3.

*----------------------------------------------------------------------*
* Global Data
*----------------------------------------------------------------------*
DATA: gt_excel_raw   TYPE TABLE OF ty_excel_raw,
      gt_upload_data TYPE TABLE OF ty_upload_data,
      gt_purchase    TYPE ygms_tt_purchase,
      gv_success     TYPE i,
      gv_error       TYPE i,
      gv_total       TYPE i.

*----------------------------------------------------------------------*
* At Selection Screen on Value Request
*----------------------------------------------------------------------*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f4_file_path.

*----------------------------------------------------------------------*
* At Selection Screen
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  IF p_templ = abap_true.
    PERFORM download_template.
    LEAVE LIST-PROCESSING.
  ENDIF.

*----------------------------------------------------------------------*
* Start of Selection
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM upload_excel.
  PERFORM validate_data.
  PERFORM display_results.

  IF p_save = abap_true AND gv_error = 0.
    PERFORM save_data.
  ENDIF.

*&---------------------------------------------------------------------*
*& Form F4_FILE_PATH
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
*& Form DOWNLOAD_TEMPLATE
*&---------------------------------------------------------------------*
FORM download_template.
  DATA: lt_template TYPE TABLE OF ty_excel_raw,
        ls_template TYPE ty_excel_raw,
        lv_filename TYPE string,
        lv_path     TYPE string,
        lv_fullpath TYPE string,
        lv_action   TYPE i.

  " Header row
  ls_template-col1  = 'GAS_DAY'.
  ls_template-col2  = 'LOCATION_ID'.
  ls_template-col3  = 'MATERIAL'.
  ls_template-col4  = 'STATE'.
  ls_template-col5  = 'STATE_CODE'.
  ls_template-col6  = 'QTY_MMBTU'.
  ls_template-col7  = 'QTY_SCM'.
  ls_template-col8  = 'GCV'.
  ls_template-col9  = 'NCV'.
  ls_template-col10 = 'TAX_TYPE'.
  APPEND ls_template TO lt_template.

  " Sample data row
  CLEAR ls_template.
  ls_template-col1  = '20260115'.
  ls_template-col2  = 'LOC001'.
  ls_template-col3  = '000000000000001234'.
  ls_template-col4  = 'Gujarat'.
  ls_template-col5  = 'GJ'.
  ls_template-col6  = '1000.500'.
  ls_template-col7  = '28000.000'.
  ls_template-col8  = '9500.000'.
  ls_template-col9  = '8500.000'.
  ls_template-col10 = 'CST'.
  APPEND ls_template TO lt_template.

  " Get save path
  cl_gui_frontend_services=>file_save_dialog(
    EXPORTING
      window_title         = 'Save Template'
      default_extension    = 'XLS'
      default_file_name    = 'CST_Upload_Template'
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
    " Download template
    CALL FUNCTION 'GUI_DOWNLOAD'
      EXPORTING
        filename                = lv_fullpath
        filetype                = 'ASC'
        write_field_separator   = 'X'
      TABLES
        data_tab                = lt_template
      EXCEPTIONS
        OTHERS                  = 1.

    IF sy-subrc = 0.
      MESSAGE 'Template downloaded successfully' TYPE 'S'.
    ELSE.
      MESSAGE 'Error downloading template' TYPE 'E'.
    ENDIF.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form UPLOAD_EXCEL
*&---------------------------------------------------------------------*
FORM upload_excel.
  DATA: lt_raw_data TYPE truxs_t_text_data.

  CALL FUNCTION 'TEXT_CONVERT_XLS_TO_SAP'
    EXPORTING
      i_line_header        = 'X'
      i_tab_raw_data       = lt_raw_data
      i_filename           = p_file
    TABLES
      i_tab_converted_data = gt_excel_raw
    EXCEPTIONS
      conversion_failed    = 1
      OTHERS               = 2.

  IF sy-subrc <> 0.
    MESSAGE 'Error uploading Excel file' TYPE 'E'.
  ENDIF.

  gv_total = lines( gt_excel_raw ).
  MESSAGE |{ gv_total } records read from Excel| TYPE 'S'.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form VALIDATE_DATA
*&---------------------------------------------------------------------*
FORM validate_data.
  DATA: ls_upload TYPE ty_upload_data.

  LOOP AT gt_excel_raw INTO DATA(ls_raw).
    CLEAR ls_upload.

    " Convert Gas Day
    IF ls_raw-col1 IS NOT INITIAL.
      CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
        EXPORTING
          date_external            = ls_raw-col1
        IMPORTING
          date_internal            = ls_upload-gas_day
        EXCEPTIONS
          date_external_is_invalid = 1
          OTHERS                   = 2.
      IF sy-subrc <> 0.
        " Try direct assignment for YYYYMMDD format
        ls_upload-gas_day = ls_raw-col1.
      ENDIF.
    ENDIF.

    " Map other fields
    ls_upload-location_id = ls_raw-col2.
    ls_upload-material    = |{ ls_raw-col3 ALPHA = IN }|.
    ls_upload-state       = ls_raw-col4.
    ls_upload-state_code  = ls_raw-col5.
    ls_upload-tax_type    = ls_raw-col6.

    " Convert numeric fields
    TRY.
        ls_upload-qty_mbg = ls_raw-col6.
        ls_upload-qty_scm = ls_raw-col7.
        ls_upload-gcv     = ls_raw-col8.
        ls_upload-ncv     = ls_raw-col9.
      CATCH cx_root.
        ls_upload-status  = 'E'.
        ls_upload-message = 'Invalid numeric value'.
    ENDTRY.

    ls_upload-tax_type = ls_raw-col10.

    " Validation checks
    IF ls_upload-gas_day IS INITIAL.
      ls_upload-status  = 'E'.
      ls_upload-message = 'Gas Day is required'.
    ELSEIF ls_upload-location_id IS INITIAL.
      ls_upload-status  = 'E'.
      ls_upload-message = 'Location ID is required'.
    ELSEIF ls_upload-material IS INITIAL.
      ls_upload-status  = 'E'.
      ls_upload-message = 'Material is required'.
    ELSEIF ls_upload-state_code IS INITIAL.
      ls_upload-status  = 'E'.
      ls_upload-message = 'State Code is required'.
    ELSEIF ls_upload-qty_mbg <= 0.
      ls_upload-status  = 'E'.
      ls_upload-message = 'Quantity MMBTU must be positive'.
    ELSE.
      ls_upload-status  = 'S'.
      ls_upload-message = 'Valid'.
    ENDIF.

    " Count status
    IF ls_upload-status = 'E'.
      gv_error = gv_error + 1.
    ELSE.
      gv_success = gv_success + 1.
    ENDIF.

    APPEND ls_upload TO gt_upload_data.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form DISPLAY_RESULTS
*&---------------------------------------------------------------------*
FORM display_results.
  DATA: lo_alv       TYPE REF TO cl_salv_table,
        lo_functions TYPE REF TO cl_salv_functions_list,
        lo_columns   TYPE REF TO cl_salv_columns_table,
        lo_column    TYPE REF TO cl_salv_column_table.

  " Display summary
  WRITE: / 'Upload Summary:'.
  WRITE: / '==============='.
  WRITE: / 'Total Records: ', gv_total.
  WRITE: / 'Successful:    ', gv_success.
  WRITE: / 'Errors:        ', gv_error.
  SKIP.

  IF p_save = abap_true AND gv_error > 0.
    WRITE: / 'Cannot save - please fix errors first!' COLOR COL_NEGATIVE.
    SKIP.
  ENDIF.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = gt_upload_data
      ).

      " Enable functions
      lo_functions = lo_alv->get_functions( ).
      lo_functions->set_all( abap_true ).

      " Optimize columns
      lo_columns = lo_alv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      " Set status column color
      TRY.
          lo_column ?= lo_columns->get_column( 'STATUS' ).
          lo_column->set_short_text( 'Status' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      TRY.
          lo_column ?= lo_columns->get_column( 'MESSAGE' ).
          lo_column->set_short_text( 'Message' ).
          lo_column->set_long_text( 'Validation Message' ).
        CATCH cx_salv_not_found.
      ENDTRY.

      lo_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv TYPE 'E'.
  ENDTRY.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form SAVE_DATA
*&---------------------------------------------------------------------*
FORM save_data.
  DATA: ls_purchase TYPE ygms_cst_pur,
        lv_gail_id  TYPE ygms_de_gail_id,
        lv_guid     TYPE guid_16,
        lv_random   TYPE i.

  " Generate GAIL ID using GUID_CREATE function
  CALL FUNCTION 'GUID_CREATE'
    IMPORTING
      ev_guid_16 = lv_guid.

  IF lv_guid IS INITIAL.
    " Fallback: Generate ID from timestamp and random number
    CALL FUNCTION 'GENERAL_GET_RANDOM_INT'
      EXPORTING
        range  = 9999
      IMPORTING
        random = lv_random.
    lv_gail_id = |GAIL-{ sy-datum }-{ sy-uzeit }-{ lv_random }|.
  ELSE.
    lv_gail_id = |GAIL-{ sy-datum }-{ sy-uzeit }-{ lv_guid+0(4) }|.
  ENDIF.

  " Prepare purchase records
  LOOP AT gt_upload_data INTO DATA(ls_upload) WHERE status = 'S'.
    CLEAR ls_purchase.
    ls_purchase-mandt       = sy-mandt.
    ls_purchase-gail_id     = lv_gail_id.
    ls_purchase-gas_day     = ls_upload-gas_day.
    ls_purchase-location_id = ls_upload-location_id.
    ls_purchase-material    = ls_upload-material.
    ls_purchase-state       = ls_upload-state.
    ls_purchase-state_code  = ls_upload-state_code.
    ls_purchase-qty_mbg     = ls_upload-qty_mbg.
    ls_purchase-gcv         = ls_upload-gcv.
    ls_purchase-ncv         = ls_upload-ncv.
    ls_purchase-qty_scm     = ls_upload-qty_scm.
    ls_purchase-tax_type    = ls_upload-tax_type.
    ls_purchase-alloc_pct   = 100.
    ls_purchase-ernam       = sy-uname.
    ls_purchase-erdat       = sy-datum.
    ls_purchase-erzet       = sy-uzeit.

    APPEND ls_purchase TO gt_purchase.
  ENDLOOP.

  " Save to database
  IF gt_purchase IS NOT INITIAL.
    MODIFY ygms_cst_pur FROM TABLE gt_purchase.
    IF sy-subrc = 0.
      COMMIT WORK AND WAIT.
      MESSAGE |{ gv_success } records saved with GAIL ID: { lv_gail_id }| TYPE 'S'.
    ELSE.
      ROLLBACK WORK.
      MESSAGE 'Error saving data to database' TYPE 'E'.
    ENDIF.
  ENDIF.
ENDFORM.
