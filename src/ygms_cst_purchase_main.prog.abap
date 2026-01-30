*&---------------------------------------------------------------------*
*& Report YGMS_CST_PURCHASE_MAIN
*& Description: ONGC CST Purchase Data Sharing - Main Program
*&---------------------------------------------------------------------*
REPORT ygms_cst_purchase_main.

*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS:     p_loc    TYPE ygms_de_loc_id OBLIGATORY.
  SELECT-OPTIONS: s_date   FOR sy-datum OBLIGATORY.
  SELECT-OPTIONS: s_exst   FOR sy-langu NO INTERVALS.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  PARAMETERS: p_disp RADIOBUTTON GROUP rb1 DEFAULT 'X',
              p_save RADIOBUTTON GROUP rb1,
              p_send RADIOBUTTON GROUP rb1.
  PARAMETERS: p_email TYPE ad_smtpadr.
SELECTION-SCREEN END OF BLOCK b2.

*----------------------------------------------------------------------*
* Global Data
*----------------------------------------------------------------------*
DATA: go_controller  TYPE REF TO ygms_cl_cst_controller,
      gt_allocation  TYPE ygms_tt_allocation,
      gt_messages    TYPE bapiret2_t,
      gv_gail_id     TYPE ygms_de_gail_id.

*----------------------------------------------------------------------*
* Initialization
*----------------------------------------------------------------------*
INITIALIZATION.
  TEXT-001 = 'Selection Criteria'.
  TEXT-002 = 'Processing Options'.

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
      " Execute allocation
      go_controller->execute_allocation(
        EXPORTING
          it_excluded_states = s_exst[]
        IMPORTING
          et_allocation      = gt_allocation
          et_messages        = gt_messages
      ).

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
*& Form DISPLAY_ALV
*&---------------------------------------------------------------------*
FORM display_alv.
  DATA: lo_alv       TYPE REF TO cl_salv_table,
        lo_functions TYPE REF TO cl_salv_functions_list,
        lo_columns   TYPE REF TO cl_salv_columns_table,
        lo_column    TYPE REF TO cl_salv_column.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = gt_allocation
      ).

      " Enable all functions
      lo_functions = lo_alv->get_functions( ).
      lo_functions->set_all( abap_true ).

      " Set column texts
      lo_columns = lo_alv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      TRY.
          lo_column = lo_columns->get_column( 'GAS_DAY' ).
          lo_column->set_short_text( 'Gas Day' ).
          lo_column->set_medium_text( 'Gas Day' ).
          lo_column->set_long_text( 'Gas Day' ).
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

      " Display
      lo_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv TYPE 'E'.
  ENDTRY.
ENDFORM.
