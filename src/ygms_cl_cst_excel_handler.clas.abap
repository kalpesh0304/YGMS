CLASS ygms_cl_cst_excel_handler DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_excel_row,
        gas_day     TYPE datum,
        location_id TYPE ygms_de_loc_id,
        material    TYPE matnr,
        state       TYPE ygms_de_state,
        state_code  TYPE ygms_de_state_cd,
        qty_mbg     TYPE ygms_de_qty_mbg,
        qty_scm     TYPE ygms_de_qty_scm,
        gcv         TYPE ygms_de_gcv,
        ncv         TYPE ygms_de_ncv,
        tax_type    TYPE ygms_de_tax_type,
      END OF ty_excel_row,
      tt_excel_rows TYPE STANDARD TABLE OF ty_excel_row WITH DEFAULT KEY.

    METHODS constructor.

    METHODS upload_file
      IMPORTING
        iv_file_path TYPE string
      EXPORTING
        et_data      TYPE tt_excel_rows
        et_messages  TYPE bapiret2_t
      RAISING
        ygms_cx_cst_error.

    METHODS validate_data
      IMPORTING
        it_data       TYPE tt_excel_rows
      EXPORTING
        et_valid      TYPE tt_excel_rows
        et_invalid    TYPE ygms_tt_validation
        et_messages   TYPE bapiret2_t.

    METHODS download_template
      IMPORTING
        iv_file_path TYPE string
      EXPORTING
        et_messages  TYPE bapiret2_t
      RAISING
        ygms_cx_cst_error.

    METHODS convert_to_purchase
      IMPORTING
        it_data     TYPE tt_excel_rows
      EXPORTING
        et_purchase TYPE ygms_tt_purchase
      RAISING
        ygms_cx_cst_error.

  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA: mv_has_header TYPE abap_bool.

    METHODS parse_date
      IMPORTING
        iv_date_string TYPE string
      RETURNING
        VALUE(rv_date) TYPE datum.

    METHODS parse_number
      IMPORTING
        iv_number_string TYPE string
      RETURNING
        VALUE(rv_number) TYPE p LENGTH 15 DECIMALS 3.

    METHODS add_message
      IMPORTING
        iv_type    TYPE symsgty
        iv_id      TYPE symsgid
        iv_number  TYPE symsgno
        iv_message TYPE string
      CHANGING
        ct_messages TYPE bapiret2_t.

ENDCLASS.

CLASS ygms_cl_cst_excel_handler IMPLEMENTATION.

  METHOD constructor.
    mv_has_header = abap_true.
  ENDMETHOD.

  METHOD upload_file.
    DATA: lt_raw_data   TYPE truxs_t_text_data,
          lt_excel_raw  TYPE TABLE OF alsmex_tabline,
          ls_excel_row  TYPE ty_excel_row,
          lv_filename   TYPE rlgrap-filename.

    CLEAR: et_data, et_messages.

    IF iv_file_path IS INITIAL.
      RAISE EXCEPTION TYPE ygms_cx_cst_error
        EXPORTING
          textid = ygms_cx_cst_error=>file_not_found.
    ENDIF.

    lv_filename = iv_file_path.

    " Upload Excel file using standard function
    CALL FUNCTION 'TEXT_CONVERT_XLS_TO_SAP'
      EXPORTING
        i_line_header        = COND #( WHEN mv_has_header = abap_true THEN 'X' ELSE ' ' )
        i_tab_raw_data       = lt_raw_data
        i_filename           = lv_filename
      TABLES
        i_tab_converted_data = et_data
      EXCEPTIONS
        conversion_failed    = 1
        OTHERS               = 2.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE ygms_cx_cst_error
        EXPORTING
          textid = ygms_cx_cst_error=>upload_failed.
    ENDIF.

    " Add success message
    add_message(
      EXPORTING
        iv_type    = 'S'
        iv_id      = 'YGMS_CST'
        iv_number  = '001'
        iv_message = |{ lines( et_data ) } records uploaded successfully|
      CHANGING
        ct_messages = et_messages
    ).
  ENDMETHOD.

  METHOD validate_data.
    DATA: ls_validation TYPE ygms_s_validation,
          ls_valid      TYPE ty_excel_row,
          lv_row        TYPE i,
          lv_has_error  TYPE abap_bool.

    CLEAR: et_valid, et_invalid, et_messages.

    LOOP AT it_data INTO DATA(ls_data).
      lv_row = sy-tabix.
      lv_has_error = abap_false.

      " Validate Gas Day
      IF ls_data-gas_day IS INITIAL.
        CLEAR ls_validation.
        ls_validation-row_num     = lv_row.
        ls_validation-field_name  = 'GAS_DAY'.
        ls_validation-msg_type    = 'E'.
        ls_validation-message     = 'Gas Day is required'.
        ls_validation-is_error    = abap_true.
        APPEND ls_validation TO et_invalid.
        lv_has_error = abap_true.
      ENDIF.

      " Validate Location ID
      IF ls_data-location_id IS INITIAL.
        CLEAR ls_validation.
        ls_validation-row_num     = lv_row.
        ls_validation-field_name  = 'LOCATION_ID'.
        ls_validation-msg_type    = 'E'.
        ls_validation-message     = 'Location ID is required'.
        ls_validation-is_error    = abap_true.
        APPEND ls_validation TO et_invalid.
        lv_has_error = abap_true.
      ENDIF.

      " Validate Material
      IF ls_data-material IS INITIAL.
        CLEAR ls_validation.
        ls_validation-row_num     = lv_row.
        ls_validation-field_name  = 'MATERIAL'.
        ls_validation-msg_type    = 'E'.
        ls_validation-message     = 'Material is required'.
        ls_validation-is_error    = abap_true.
        APPEND ls_validation TO et_invalid.
        lv_has_error = abap_true.
      ENDIF.

      " Validate State Code
      IF ls_data-state_code IS INITIAL.
        CLEAR ls_validation.
        ls_validation-row_num     = lv_row.
        ls_validation-field_name  = 'STATE_CODE'.
        ls_validation-msg_type    = 'E'.
        ls_validation-message     = 'State Code is required'.
        ls_validation-is_error    = abap_true.
        APPEND ls_validation TO et_invalid.
        lv_has_error = abap_true.
      ENDIF.

      " Validate Quantity
      IF ls_data-qty_mbg <= 0.
        CLEAR ls_validation.
        ls_validation-row_num     = lv_row.
        ls_validation-field_name  = 'QTY_MBG'.
        ls_validation-msg_type    = 'E'.
        ls_validation-message     = 'Quantity MMBTU must be positive'.
        ls_validation-is_error    = abap_true.
        APPEND ls_validation TO et_invalid.
        lv_has_error = abap_true.
      ENDIF.

      IF lv_has_error = abap_false.
        APPEND ls_data TO et_valid.
      ENDIF.
    ENDLOOP.

    " Add summary message
    DATA(lv_valid_count) = lines( et_valid ).
    DATA(lv_error_count) = lines( et_invalid ).

    add_message(
      EXPORTING
        iv_type    = COND #( WHEN lv_error_count > 0 THEN 'W' ELSE 'S' )
        iv_id      = 'YGMS_CST'
        iv_number  = '002'
        iv_message = |Validation: { lv_valid_count } valid, { lv_error_count } errors|
      CHANGING
        ct_messages = et_messages
    ).
  ENDMETHOD.

  METHOD download_template.
    DATA: lt_template TYPE TABLE OF ty_excel_row,
          ls_template TYPE ty_excel_row,
          lv_fullpath TYPE string.

    CLEAR et_messages.

    " Create sample template data
    ls_template-gas_day     = sy-datum.
    ls_template-location_id = 'LOC001'.
    ls_template-material    = '000000000000001234'.
    ls_template-state       = 'Gujarat'.
    ls_template-state_code  = 'GJ'.
    ls_template-qty_mbg     = '1000.500'.
    ls_template-qty_scm     = '28000.000'.
    ls_template-gcv         = '9500.000'.
    ls_template-ncv         = '8500.000'.
    ls_template-tax_type    = 'CST'.
    APPEND ls_template TO lt_template.

    lv_fullpath = iv_file_path.

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

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE ygms_cx_cst_error
        EXPORTING
          textid = ygms_cx_cst_error=>download_failed.
    ENDIF.

    add_message(
      EXPORTING
        iv_type    = 'S'
        iv_id      = 'YGMS_CST'
        iv_number  = '003'
        iv_message = 'Template downloaded successfully'
      CHANGING
        ct_messages = et_messages
    ).
  ENDMETHOD.

  METHOD convert_to_purchase.
    DATA: ls_purchase TYPE ygms_cst_pur,
          lv_guid     TYPE guid_16.

    CLEAR et_purchase.

    " Generate GAIL ID
    TRY.
        lv_guid = cl_system_uuid=>create_uuid_c16_static( ).
      CATCH cx_uuid_error.
        lv_guid = |{ sy-datum }{ sy-uzeit }{ sy-uname+0(4) }|.
    ENDTRY.

    DATA(lv_gail_id) = |GAIL-{ sy-datum }-{ sy-uzeit }-{ lv_guid+0(4) }|.

    LOOP AT it_data INTO DATA(ls_data).
      CLEAR ls_purchase.
      ls_purchase-mandt       = sy-mandt.
      ls_purchase-gail_id     = lv_gail_id.
      ls_purchase-gas_day     = ls_data-gas_day.
      ls_purchase-location_id = ls_data-location_id.
      ls_purchase-material    = ls_data-material.
      ls_purchase-state       = ls_data-state.
      ls_purchase-state_code  = ls_data-state_code.
      ls_purchase-qty_mbg     = ls_data-qty_mbg.
      ls_purchase-qty_scm     = ls_data-qty_scm.
      ls_purchase-gcv         = ls_data-gcv.
      ls_purchase-ncv         = ls_data-ncv.
      ls_purchase-tax_type    = ls_data-tax_type.
      ls_purchase-alloc_pct   = 100.
      ls_purchase-ernam       = sy-uname.
      ls_purchase-erdat       = sy-datum.
      ls_purchase-erzet       = sy-uzeit.

      APPEND ls_purchase TO et_purchase.
    ENDLOOP.
  ENDMETHOD.

  METHOD parse_date.
    DATA: lv_date_str TYPE string.

    rv_date = '00000000'.
    lv_date_str = iv_date_string.

    " Try standard conversion first
    CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
      EXPORTING
        date_external            = lv_date_str
      IMPORTING
        date_internal            = rv_date
      EXCEPTIONS
        date_external_is_invalid = 1
        OTHERS                   = 2.

    IF sy-subrc <> 0.
      " Try direct assignment for YYYYMMDD format
      IF strlen( lv_date_str ) = 8.
        rv_date = lv_date_str.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD parse_number.
    DATA: lv_num_str TYPE string.

    rv_number = 0.
    lv_num_str = iv_number_string.

    " Remove thousands separators
    REPLACE ALL OCCURRENCES OF ',' IN lv_num_str WITH ''.

    TRY.
        rv_number = lv_num_str.
      CATCH cx_root.
        rv_number = 0.
    ENDTRY.
  ENDMETHOD.

  METHOD add_message.
    DATA: ls_message TYPE bapiret2.

    ls_message-type       = iv_type.
    ls_message-id         = iv_id.
    ls_message-number     = iv_number.
    ls_message-message    = iv_message.
    APPEND ls_message TO ct_messages.
  ENDMETHOD.

ENDCLASS.
