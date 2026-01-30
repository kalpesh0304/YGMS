CLASS ygms_cl_cst_controller DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES ygms_if_cst_processor.

    "! <p class="shorttext synchronized" lang="en">Constructor</p>
    METHODS constructor.

    "! <p class="shorttext synchronized" lang="en">Set selection parameters</p>
    METHODS set_selection
      IMPORTING
        iv_location_id TYPE ygms_de_loc_id
        iv_date_from   TYPE datum
        iv_date_to     TYPE datum.

    "! <p class="shorttext synchronized" lang="en">Execute allocation process</p>
    METHODS execute_allocation
      IMPORTING
        it_excluded_states TYPE ygms_tt_state_excl OPTIONAL
      EXPORTING
        et_allocation      TYPE ygms_tt_allocation
        et_messages        TYPE bapiret2_t
      RAISING
        ygms_cx_cst_error.

    "! <p class="shorttext synchronized" lang="en">Save data to database</p>
    METHODS save_data
      IMPORTING
        it_data     TYPE ygms_tt_allocation
      EXPORTING
        ev_gail_id  TYPE ygms_de_gail_id
        et_messages TYPE bapiret2_t
      RAISING
        ygms_cx_cst_error.

    "! <p class="shorttext synchronized" lang="en">Send data via email</p>
    METHODS send_data
      IMPORTING
        iv_email_address TYPE ad_smtpadr OPTIONAL
      EXPORTING
        et_messages      TYPE bapiret2_t
      RAISING
        ygms_cx_cst_error.

    "! <p class="shorttext synchronized" lang="en">Check authorization</p>
    METHODS check_authorization
      IMPORTING
        iv_location_id TYPE ygms_de_loc_id
        iv_activity    TYPE activ_auth
      RETURNING
        VALUE(rv_authorized) TYPE abap_bool.

  PRIVATE SECTION.
    DATA: mv_location_id TYPE ygms_de_loc_id,
          mv_date_from   TYPE datum,
          mv_date_to     TYPE datum,
          mt_messages    TYPE bapiret2_t,
          mo_data_handler  TYPE REF TO ygms_cl_cst_data_handler,
          mo_allocator     TYPE REF TO ygms_cl_cst_allocator,
          mo_validator     TYPE REF TO ygms_cl_cst_validator,
          mo_audit_handler TYPE REF TO ygms_cl_cst_audit_handler,
          mo_email_sender  TYPE REF TO ygms_cl_cst_email_sender.

    "! <p class="shorttext synchronized" lang="en">Add message to message table</p>
    METHODS add_message
      IMPORTING
        iv_type   TYPE symsgty
        iv_id     TYPE symsgid
        iv_number TYPE symsgno
        iv_v1     TYPE clike OPTIONAL
        iv_v2     TYPE clike OPTIONAL.

    "! <p class="shorttext synchronized" lang="en">Generate GAIL ID</p>
    METHODS generate_gail_id
      RETURNING
        VALUE(rv_gail_id) TYPE ygms_de_gail_id.

ENDCLASS.


CLASS ygms_cl_cst_controller IMPLEMENTATION.

  METHOD constructor.
    " Initialize helper objects
    mo_data_handler  = NEW ygms_cl_cst_data_handler( ).
    mo_allocator     = NEW ygms_cl_cst_allocator( ).
    mo_validator     = NEW ygms_cl_cst_validator( ).
    mo_audit_handler = NEW ygms_cl_cst_audit_handler( ).
    mo_email_sender  = NEW ygms_cl_cst_email_sender( ).
  ENDMETHOD.


  METHOD set_selection.
    mv_location_id = iv_location_id.
    mv_date_from   = iv_date_from.
    mv_date_to     = iv_date_to.
  ENDMETHOD.


  METHOD ygms_if_cst_processor~initialize.
    set_selection(
      iv_location_id = iv_location_id
      iv_date_from   = iv_date_from
      iv_date_to     = iv_date_to
    ).
  ENDMETHOD.


  METHOD ygms_if_cst_processor~process.
    TRY.
        execute_allocation(
          IMPORTING
            et_allocation = DATA(lt_allocation)
            et_messages   = mt_messages
        ).

        " Convert allocation to purchase format
        LOOP AT lt_allocation INTO DATA(ls_alloc).
          APPEND INITIAL LINE TO rt_result ASSIGNING FIELD-SYMBOL(<ls_result>).
          MOVE-CORRESPONDING ls_alloc TO <ls_result>.
          <ls_result>-qty_mbg = ls_alloc-alloc_qty_mbg.
          <ls_result>-qty_scm = ls_alloc-alloc_qty_scm.
        ENDLOOP.

      CATCH ygms_cx_cst_error INTO DATA(lx_error).
        add_message(
          iv_type   = 'E'
          iv_id     = 'YGMS_MSG'
          iv_number = '011'
          iv_v1     = lx_error->get_text( )
        ).
    ENDTRY.
  ENDMETHOD.


  METHOD ygms_if_cst_processor~validate.
    rv_valid = mo_validator->validate_allocation( it_data ).
  ENDMETHOD.


  METHOD ygms_if_cst_processor~get_messages.
    rt_messages = mt_messages.
  ENDMETHOD.


  METHOD execute_allocation.
    CLEAR: et_allocation, et_messages.

    " Check authorization
    IF check_authorization( iv_location_id = mv_location_id
                            iv_activity    = ygms_if_cst_constants=>gc_activity-display ) = abap_false.
      RAISE EXCEPTION TYPE ygms_cx_cst_error
        EXPORTING
          textid    = ygms_cx_cst_error=>auth_error
          mv_param1 = CONV #( mv_location_id ).
    ENDIF.

    " Validate date range
    IF mv_date_from > mv_date_to.
      RAISE EXCEPTION TYPE ygms_cx_cst_validation
        EXPORTING
          textid    = ygms_cx_cst_validation=>invalid_date_range
          mv_param1 = CONV #( mv_date_from )
          mv_param2 = CONV #( mv_date_to ).
    ENDIF.

    " Get B2B receipt data
    DATA(lt_b2b_data) = mo_data_handler->get_b2b_data(
      iv_location_id = mv_location_id
      iv_date_from   = mv_date_from
      iv_date_to     = mv_date_to
    ).

    IF lt_b2b_data IS INITIAL.
      add_message(
        iv_type   = 'W'
        iv_id     = 'YGMS_MSG'
        iv_number = '002'
      ).
      et_messages = mt_messages.
      RETURN.
    ENDIF.

    " Get material mapping for state allocation
    DATA(lt_mat_map) = mo_data_handler->get_material_mapping( mv_location_id ).

    " Perform state-wise allocation
    et_allocation = mo_allocator->allocate(
      it_b2b_data        = lt_b2b_data
      it_mat_map         = lt_mat_map
      it_excluded_states = it_excluded_states
    ).

    " Validate allocation
    IF mo_validator->validate_totals(
         it_b2b_data    = lt_b2b_data
         it_allocation  = et_allocation ) = abap_false.
      add_message(
        iv_type   = 'W'
        iv_id     = 'YGMS_MSG'
        iv_number = '009'
        iv_v1     = 'Allocation'
        iv_v2     = 'Supply'
      ).
    ELSE.
      add_message(
        iv_type   = 'S'
        iv_id     = 'YGMS_MSG'
        iv_number = '017'
        iv_v1     = CONV #( lines( et_allocation ) )
      ).
    ENDIF.

    et_messages = mt_messages.
  ENDMETHOD.


  METHOD save_data.
    CLEAR: ev_gail_id, et_messages.

    " Check authorization for change
    IF check_authorization( iv_location_id = mv_location_id
                            iv_activity    = ygms_if_cst_constants=>gc_activity-change ) = abap_false.
      RAISE EXCEPTION TYPE ygms_cx_cst_error
        EXPORTING
          textid    = ygms_cx_cst_error=>auth_error
          mv_param1 = CONV #( mv_location_id ).
    ENDIF.

    " Generate GAIL ID
    ev_gail_id = generate_gail_id( ).

    " Prepare purchase data
    DATA: lt_purchase TYPE ygms_tt_purchase.

    LOOP AT it_data INTO DATA(ls_alloc) WHERE excluded = abap_false.
      APPEND INITIAL LINE TO lt_purchase ASSIGNING FIELD-SYMBOL(<ls_pur>).
      <ls_pur>-mandt       = sy-mandt.
      <ls_pur>-gail_id     = ev_gail_id.
      <ls_pur>-gas_day     = ls_alloc-gas_day.
      <ls_pur>-location_id = ls_alloc-location_id.
      <ls_pur>-material    = ls_alloc-material.
      <ls_pur>-state       = ls_alloc-state.
      <ls_pur>-state_code  = ls_alloc-state_code.
      <ls_pur>-qty_mbg     = ls_alloc-alloc_qty_mbg.
      <ls_pur>-gcv         = ls_alloc-gcv.
      <ls_pur>-ncv         = ls_alloc-ncv.
      <ls_pur>-qty_scm     = ls_alloc-alloc_qty_scm.
      <ls_pur>-tax_type    = ls_alloc-tax_type.
      <ls_pur>-alloc_pct   = ls_alloc-alloc_pct.
      <ls_pur>-ernam       = sy-uname.
      <ls_pur>-erdat       = sy-datum.
      <ls_pur>-erzet       = sy-uzeit.
    ENDLOOP.

    " Save to database
    mo_data_handler->save_purchase_data( lt_purchase ).

    " Log audit
    mo_audit_handler->log_insert(
      iv_table_name = ygms_if_cst_constants=>gc_tables-purchase
      iv_key1       = CONV #( ev_gail_id )
      iv_key2       = CONV #( mv_location_id )
    ).

    add_message(
      iv_type   = 'S'
      iv_id     = 'YGMS_MSG'
      iv_number = '010'
      iv_v1     = CONV #( ev_gail_id )
    ).

    et_messages = mt_messages.
  ENDMETHOD.


  METHOD send_data.
    CLEAR et_messages.

    TRY.
        mo_email_sender->send(
          iv_email_address = iv_email_address
          iv_location_id   = mv_location_id
          iv_date_from     = mv_date_from
          iv_date_to       = mv_date_to
        ).

        add_message(
          iv_type   = 'S'
          iv_id     = 'YGMS_MSG'
          iv_number = '013'
          iv_v1     = CONV #( iv_email_address )
        ).

      CATCH cx_root INTO DATA(lx_error).
        RAISE EXCEPTION TYPE ygms_cx_cst_error
          EXPORTING
            textid    = ygms_cx_cst_error=>general_error
            mv_param1 = lx_error->get_text( ).
    ENDTRY.

    et_messages = mt_messages.
  ENDMETHOD.


  METHOD check_authorization.
    " Check location authorization
    AUTHORITY-CHECK OBJECT ygms_if_cst_constants=>gc_auth_object-location
      ID 'LOCID' FIELD iv_location_id
      ID 'ACTVT' FIELD iv_activity.

    rv_authorized = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD add_message.
    APPEND VALUE #(
      type   = iv_type
      id     = iv_id
      number = iv_number
      message_v1 = iv_v1
      message_v2 = iv_v2
    ) TO mt_messages.
  ENDMETHOD.


  METHOD generate_gail_id.
    " Generate unique GAIL ID: GAIL-YYYYMMDD-HHMMSS-NNNN
    DATA: lv_guid TYPE guid_16.

    TRY.
        lv_guid = cl_system_uuid=>create_uuid_c16_static( ).
      CATCH cx_uuid_error.
        lv_guid = |{ sy-datum }{ sy-uzeit }{ sy-uname+0(4) }|.
    ENDTRY.

    rv_gail_id = |{ ygms_if_cst_constants=>gc_gail_id_prefix }-| &&
                 |{ sy-datum }-{ sy-uzeit }-{ lv_guid+0(4) }|.
  ENDMETHOD.

ENDCLASS.
