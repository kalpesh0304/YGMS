CLASS ygms_cl_cst_validator DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! <p class="shorttext synchronized" lang="en">Validate allocation data</p>
    METHODS validate_allocation
      IMPORTING
        it_data        TYPE ygms_tt_purchase
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! <p class="shorttext synchronized" lang="en">Validate totals match</p>
    METHODS validate_totals
      IMPORTING
        it_b2b_data    TYPE ygms_tt_b2b
        it_allocation  TYPE ygms_tt_allocation
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

ENDCLASS.


CLASS ygms_cl_cst_validator IMPLEMENTATION.

  METHOD validate_allocation.
    rv_valid = abap_true.

    LOOP AT it_data INTO DATA(ls_data).
      " Validate required fields
      IF ls_data-location_id IS INITIAL OR
         ls_data-gas_day IS INITIAL OR
         ls_data-state IS INITIAL.
        rv_valid = abap_false.
        EXIT.
      ENDIF.

      " Validate quantities are positive
      IF ls_data-qty_mbg < 0 OR ls_data-qty_scm < 0.
        rv_valid = abap_false.
        EXIT.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validate_totals.
    DATA: lv_b2b_total_mbg   TYPE ygms_de_qty_mbg,
          lv_alloc_total_mbg TYPE ygms_de_qty_mbg.

    " Sum B2B quantities
    LOOP AT it_b2b_data INTO DATA(ls_b2b).
      lv_b2b_total_mbg = lv_b2b_total_mbg + ls_b2b-qty_mbg.
    ENDLOOP.

    " Sum allocation quantities (excluding excluded states)
    LOOP AT it_allocation INTO DATA(ls_alloc) WHERE excluded = abap_false.
      lv_alloc_total_mbg = lv_alloc_total_mbg + ls_alloc-alloc_qty_mbg.
    ENDLOOP.

    " Compare with tolerance
    DATA(lv_diff) = abs( lv_b2b_total_mbg - lv_alloc_total_mbg ).
    rv_valid = xsdbool( lv_diff < '0.001' ).
  ENDMETHOD.

ENDCLASS.
