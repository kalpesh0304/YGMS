CLASS ygms_cl_cst_alv_handler DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor.

    METHODS display_allocation
      IMPORTING
        it_data     TYPE ygms_tt_allocation
      RAISING
        ygms_cx_cst_error.

    METHODS display_purchase
      IMPORTING
        it_data     TYPE ygms_tt_purchase
      RAISING
        ygms_cx_cst_error.

    METHODS display_validation
      IMPORTING
        it_data     TYPE ygms_tt_validation
      RAISING
        ygms_cx_cst_error.

    METHODS display_audit_log
      IMPORTING
        it_data     TYPE ygms_tt_audit_log
      RAISING
        ygms_cx_cst_error.

    METHODS set_title
      IMPORTING
        iv_title TYPE string.

    METHODS enable_edit_mode
      IMPORTING
        iv_edit TYPE abap_bool DEFAULT abap_true.

  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA: mv_title     TYPE string,
          mv_edit_mode TYPE abap_bool.

    METHODS configure_alv
      IMPORTING
        io_alv TYPE REF TO cl_salv_table
      RAISING
        cx_salv_msg.

    METHODS set_column_texts
      IMPORTING
        io_columns TYPE REF TO cl_salv_columns_table.

ENDCLASS.

CLASS ygms_cl_cst_alv_handler IMPLEMENTATION.

  METHOD constructor.
    mv_title = 'CST Purchase Data'.
    mv_edit_mode = abap_false.
  ENDMETHOD.

  METHOD display_allocation.
    DATA: lo_alv TYPE REF TO cl_salv_table,
          lt_data TYPE ygms_tt_allocation.

    lt_data = it_data.

    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = lo_alv
          CHANGING
            t_table      = lt_data
        ).

        configure_alv( lo_alv ).
        lo_alv->display( ).

      CATCH cx_salv_msg INTO DATA(lx_salv).
        RAISE EXCEPTION TYPE ygms_cx_cst_error
          EXPORTING
            textid = ygms_cx_cst_error=>alv_error.
    ENDTRY.
  ENDMETHOD.

  METHOD display_purchase.
    DATA: lo_alv TYPE REF TO cl_salv_table,
          lt_data TYPE ygms_tt_purchase.

    lt_data = it_data.

    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = lo_alv
          CHANGING
            t_table      = lt_data
        ).

        configure_alv( lo_alv ).
        lo_alv->display( ).

      CATCH cx_salv_msg INTO DATA(lx_salv).
        RAISE EXCEPTION TYPE ygms_cx_cst_error
          EXPORTING
            textid = ygms_cx_cst_error=>alv_error.
    ENDTRY.
  ENDMETHOD.

  METHOD display_validation.
    DATA: lo_alv TYPE REF TO cl_salv_table,
          lt_data TYPE ygms_tt_validation.

    lt_data = it_data.

    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = lo_alv
          CHANGING
            t_table      = lt_data
        ).

        configure_alv( lo_alv ).

        " Set specific column texts for validation
        DATA(lo_columns) = lo_alv->get_columns( ).
        TRY.
            DATA(lo_column) = lo_columns->get_column( 'ROW_NUM' ).
            lo_column->set_short_text( 'Row' ).
            lo_column->set_medium_text( 'Row Number' ).
            lo_column->set_long_text( 'Row Number' ).
          CATCH cx_salv_not_found.
        ENDTRY.

        TRY.
            lo_column = lo_columns->get_column( 'MSG_TYPE' ).
            lo_column->set_short_text( 'Type' ).
            lo_column->set_medium_text( 'Message Type' ).
            lo_column->set_long_text( 'Message Type' ).
          CATCH cx_salv_not_found.
        ENDTRY.

        lo_alv->display( ).

      CATCH cx_salv_msg INTO DATA(lx_salv).
        RAISE EXCEPTION TYPE ygms_cx_cst_error
          EXPORTING
            textid = ygms_cx_cst_error=>alv_error.
    ENDTRY.
  ENDMETHOD.

  METHOD display_audit_log.
    DATA: lo_alv TYPE REF TO cl_salv_table,
          lt_data TYPE ygms_tt_audit_log.

    lt_data = it_data.

    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = lo_alv
          CHANGING
            t_table      = lt_data
        ).

        configure_alv( lo_alv ).
        lo_alv->display( ).

      CATCH cx_salv_msg INTO DATA(lx_salv).
        RAISE EXCEPTION TYPE ygms_cx_cst_error
          EXPORTING
            textid = ygms_cx_cst_error=>alv_error.
    ENDTRY.
  ENDMETHOD.

  METHOD set_title.
    mv_title = iv_title.
  ENDMETHOD.

  METHOD enable_edit_mode.
    mv_edit_mode = iv_edit.
  ENDMETHOD.

  METHOD configure_alv.
    DATA: lo_functions TYPE REF TO cl_salv_functions_list,
          lo_columns   TYPE REF TO cl_salv_columns_table,
          lo_display   TYPE REF TO cl_salv_display_settings.

    " Enable all standard functions
    lo_functions = io_alv->get_functions( ).
    lo_functions->set_all( abap_true ).

    " Optimize column width
    lo_columns = io_alv->get_columns( ).
    lo_columns->set_optimize( abap_true ).

    " Set column texts
    set_column_texts( lo_columns ).

    " Set display settings
    lo_display = io_alv->get_display_settings( ).
    IF mv_title IS NOT INITIAL.
      lo_display->set_list_header( CONV #( mv_title ) ).
    ENDIF.
    lo_display->set_striped_pattern( abap_true ).
  ENDMETHOD.

  METHOD set_column_texts.
    DATA: lo_column TYPE REF TO cl_salv_column.

    " GAS_DAY
    TRY.
        lo_column = io_columns->get_column( 'GAS_DAY' ).
        lo_column->set_short_text( 'Gas Day' ).
        lo_column->set_medium_text( 'Gas Day' ).
        lo_column->set_long_text( 'Gas Day' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    " LOCATION_ID
    TRY.
        lo_column = io_columns->get_column( 'LOCATION_ID' ).
        lo_column->set_short_text( 'Location' ).
        lo_column->set_medium_text( 'Location ID' ).
        lo_column->set_long_text( 'Location ID' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    " MATERIAL
    TRY.
        lo_column = io_columns->get_column( 'MATERIAL' ).
        lo_column->set_short_text( 'Material' ).
        lo_column->set_medium_text( 'Material' ).
        lo_column->set_long_text( 'Material Number' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    " STATE
    TRY.
        lo_column = io_columns->get_column( 'STATE' ).
        lo_column->set_short_text( 'State' ).
        lo_column->set_medium_text( 'State' ).
        lo_column->set_long_text( 'State Name' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    " STATE_CODE
    TRY.
        lo_column = io_columns->get_column( 'STATE_CODE' ).
        lo_column->set_short_text( 'Code' ).
        lo_column->set_medium_text( 'State Code' ).
        lo_column->set_long_text( 'State Code' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    " QTY_MBG
    TRY.
        lo_column = io_columns->get_column( 'QTY_MBG' ).
        lo_column->set_short_text( 'Qty MMBTU' ).
        lo_column->set_medium_text( 'Quantity MMBTU' ).
        lo_column->set_long_text( 'Quantity in MMBTU' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    " QTY_SCM
    TRY.
        lo_column = io_columns->get_column( 'QTY_SCM' ).
        lo_column->set_short_text( 'Qty SCM' ).
        lo_column->set_medium_text( 'Quantity SCM' ).
        lo_column->set_long_text( 'Quantity in SCM' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    " GCV
    TRY.
        lo_column = io_columns->get_column( 'GCV' ).
        lo_column->set_short_text( 'GCV' ).
        lo_column->set_medium_text( 'GCV' ).
        lo_column->set_long_text( 'Gross Calorific Value' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    " NCV
    TRY.
        lo_column = io_columns->get_column( 'NCV' ).
        lo_column->set_short_text( 'NCV' ).
        lo_column->set_medium_text( 'NCV' ).
        lo_column->set_long_text( 'Net Calorific Value' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    " TAX_TYPE
    TRY.
        lo_column = io_columns->get_column( 'TAX_TYPE' ).
        lo_column->set_short_text( 'Tax' ).
        lo_column->set_medium_text( 'Tax Type' ).
        lo_column->set_long_text( 'Tax Type' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    " ALLOC_PCT
    TRY.
        lo_column = io_columns->get_column( 'ALLOC_PCT' ).
        lo_column->set_short_text( 'Alloc %' ).
        lo_column->set_medium_text( 'Allocation %' ).
        lo_column->set_long_text( 'Allocation Percentage' ).
      CATCH cx_salv_not_found.
    ENDTRY.

    " GAIL_ID
    TRY.
        lo_column = io_columns->get_column( 'GAIL_ID' ).
        lo_column->set_short_text( 'GAIL ID' ).
        lo_column->set_medium_text( 'GAIL ID' ).
        lo_column->set_long_text( 'GAIL Transaction ID' ).
      CATCH cx_salv_not_found.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
