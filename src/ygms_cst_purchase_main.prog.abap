*&---------------------------------------------------------------------*
*& Report YGMS_CST_PURCHASE_MAIN
*& Description: ONGC CST Purchase Data - Gas Receipt Processing
*& Version: 3.1 - Removed ALV output
*&---------------------------------------------------------------------*
REPORT ygms_cst_purchase_main.

*----------------------------------------------------------------------*
* Type Definitions
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_gas_receipt,
         gas_day       TYPE datum,
         ctp_id        TYPE ygms_de_ongc_ctp,
         location_id   TYPE ygms_de_loc_id,
         ongc_material TYPE ygms_de_ongc_mat,
         material      TYPE ygms_de_gail_mat,
         qty_scm       TYPE ygms_de_qty_scm,
         gcv           TYPE ygms_de_gcv,
         ncv           TYPE ygms_de_ncv,
         qty_mbg       TYPE ygms_de_qty_mbg,
         ongc_id       TYPE c LENGTH 9,
       END OF ty_gas_receipt.

TYPES: BEGIN OF ty_loc_ctp_map,
         gail_loc_id TYPE ygms_de_loc_id,
         ongc_ctp_id TYPE ygms_de_ongc_ctp,
       END OF ty_loc_ctp_map.

TYPES: BEGIN OF ty_final,
         vstel      TYPE vbap-vstel,
         abtnr      TYPE vbkd-abtnr,
         empst      TYPE empst,
         regio      TYPE t001w-regio,
         regio_desc TYPE bezei20,
         address    TYPE char60,
         matnr1     TYPE p DECIMALS 3, "GMS_NG-Z
         matnr2     TYPE p DECIMALS 3, "GMS_NG-NWWI-Z
         matnr3     TYPE p DECIMALS 3, "GMS_NG-NAPM-WOS-Z
         matnr4     TYPE p DECIMALS 3,
         matnr5     TYPE p DECIMALS 3,
         matnr6     TYPE p DECIMALS 3,
         matnr7     TYPE p DECIMALS 3,
         matnr8     TYPE p DECIMALS 3,
         matnr9     TYPE p DECIMALS 3,
         matnr10    TYPE p DECIMALS 3,
         matnr11    TYPE p DECIMALS 3,
         matnr12    TYPE p DECIMALS 3,
         matnr13    TYPE p DECIMALS 3,
         matnr14    TYPE p DECIMALS 3,
         matnr15    TYPE p DECIMALS 3,
       END OF ty_final.


TYPES: BEGIN OF ty_final1,
         vstel      TYPE vbap-vstel,
         abtnr      TYPE vbkd-abtnr,
         empst      TYPE empst,
         regio      TYPE t001w-regio,
         regio_desc TYPE bezei20,
         address    TYPE char60,
         matnr      TYPE matnr,
         matnr1     TYPE p DECIMALS 3, "GMS_NG-Z
       END OF ty_final1.


*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
DATA: gv_loc_id TYPE ygms_de_loc_id.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: s_loc  FOR gv_loc_id,
                  s_date FOR sy-datum OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* Global Data
*----------------------------------------------------------------------*
DATA: gt_gas_receipt TYPE TABLE OF ty_gas_receipt,
      gt_loc_ctp_map TYPE TABLE OF ty_loc_ctp_map,
      gv_date_from   TYPE datum,
      gv_date_to     TYPE datum.


TYPE-POOLS : slis.
DATA: gt_fieldcat   TYPE slis_t_fieldcat_alv WITH HEADER LINE,
      it_final      TYPE TABLE OF ty_final,
      it_final_main TYPE TABLE OF ty_final1,
      wa_final_main TYPE ty_final1.

*----------------------------------------------------------------------*
* Initialization
*----------------------------------------------------------------------*
INITIALIZATION.
  " Set default date range (current month)
  DATA: lv_first_day TYPE datum.
  lv_first_day = sy-datum.
  lv_first_day+6(2) = '01'.

  s_date-sign   = 'I'.
  s_date-option = 'BT'.
  s_date-low    = lv_first_day.
  s_date-high   = sy-datum.
  APPEND s_date.

*----------------------------------------------------------------------*
* Start of Selection
*----------------------------------------------------------------------*
START-OF-SELECTION.
  " Get date range
  READ TABLE s_date INTO DATA(ls_date) INDEX 1.
  gv_date_from = ls_date-low.
  gv_date_to   = ls_date-high.

  " Step 1: Fetch Location ID - CTP ID mappings
  PERFORM fetch_location_ctp_mappings.
  CHECK gt_loc_ctp_map IS NOT INITIAL.

  " Step 2: Fetch B2B data
  PERFORM fetch_b2b_data.
  CHECK gt_gas_receipt IS NOT INITIAL.

  " Step 3: Map Location IDs to CTP IDs
  PERFORM map_location_ids.

  " Step 4: Map Material names
  PERFORM map_material_names.

* *Step 5 Fetch data from t code - YRXR098
  PERFORM fetch_data_yrxr098.

*&---------------------------------------------------------------------*
*& Form FETCH_LOCATION_CTP_MAPPINGS
*& 3.1.1 - Fetch Location ID - CTP ID combinations from YRGA_CST_LOC_MAP
*&---------------------------------------------------------------------*
FORM fetch_location_ctp_mappings.
  DATA: lt_loc_map TYPE TABLE OF yrga_cst_loc_map.

  " Fetch mappings where:
  " - From input date >= valid_from
  " - To input date <= valid_to
  " - Deletion indicator is not set
  IF s_loc[] IS NOT INITIAL.
    SELECT * FROM yrga_cst_loc_map
      INTO TABLE lt_loc_map
      WHERE gail_loc_id IN s_loc
        AND valid_from <= gv_date_from
        AND valid_to   >= gv_date_to.
*        AND deleted    = abap_false.
  ELSE.
    SELECT * FROM yrga_cst_loc_map
      INTO TABLE lt_loc_map
      WHERE valid_from <= gv_date_from
        AND valid_to   >= gv_date_to.
*        AND deleted    = abap_false.
  ENDIF.

  IF lt_loc_map IS INITIAL.
    MESSAGE s000(ygms_msg) WITH 'No valid Location-CTP mappings found for date range'.
    RETURN.
  ENDIF.

  " Build Location ID - CTP ID map
  LOOP AT lt_loc_map INTO DATA(ls_loc_map).
    DATA(ls_map) = VALUE ty_loc_ctp_map(
      gail_loc_id = ls_loc_map-gail_loc_id
      ongc_ctp_id = ls_loc_map-ongc_ctp_id
    ).
    APPEND ls_map TO gt_loc_ctp_map.
  ENDLOOP.

  DATA(lv_count) = lines( gt_loc_ctp_map ).
  MESSAGE s000(ygms_msg) WITH lv_count 'Location-CTP mappings found'.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form FETCH_B2B_DATA
*& 3.1.2 - Fetch records from YRGA_CST_B2B_1
*&---------------------------------------------------------------------*
FORM fetch_b2b_data.
  DATA: lt_b2b_data TYPE TABLE OF yrga_cst_b2b_1.
   DATA c_tgqty   TYPE msego2-adqnt.
   data i_trqty   type MSEGO2-ADQNT.
   data : LV_GCV  TYPE  OIB_PAR_FLTP,
LV_NCV  TYPE  OIB_PAR_FLTP.

  " Get unique CTP IDs
  DATA: lt_ctp_ids TYPE TABLE OF ygms_de_ongc_ctp.
  LOOP AT gt_loc_ctp_map INTO DATA(ls_map).
    COLLECT ls_map-ongc_ctp_id INTO lt_ctp_ids.
  ENDLOOP.

  " Fetch B2B data where qty_scm > 0
  IF lt_ctp_ids IS NOT INITIAL.
    SELECT * FROM yrga_cst_b2b_1
      INTO TABLE lt_b2b_data
      FOR ALL ENTRIES IN lt_ctp_ids
      WHERE ctp_id  = lt_ctp_ids-table_line
        AND gas_day BETWEEN gv_date_from AND gv_date_to
        AND qty_scm > 0.
  ENDIF.

  IF lt_b2b_data IS INITIAL.
    MESSAGE s000(ygms_msg) WITH 'No B2B data found for the selected criteria'.
    RETURN.
  ENDIF.

  " Build gas receipt table
  LOOP AT lt_b2b_data INTO DATA(ls_b2b).
    DATA(ls_receipt) = VALUE ty_gas_receipt(
      gas_day       = ls_b2b-gas_day
      ctp_id        = ls_b2b-ctp_id
      ongc_material = ls_b2b-ongc_material
      qty_scm       = ls_b2b-qty_scm
      gcv           = ls_b2b-gcv
      ncv           = ls_b2b-ncv
      ongc_id       = ls_b2b-ongc_id
    ).



i_trqty = ls_b2b-qty_scm.
lv_gcv = ls_b2b-gcv.
lv_ncv = ls_b2b-ncv.

    CALL FUNCTION 'YRX_QTY_UOM_TO_QTY_UOM'
      EXPORTING
        i_trqty = i_trqty
        i_truom = 'SM3'
        i_tguom = 'MMG'
        lv_gcv  = lv_gcv
        lv_ncv  = lv_ncv
      CHANGING
        c_tgqty = c_tgqty
*       CT_RETURN       = CT_RETURN
      .
    ls_receipt-qty_mbg = c_tgqty.

    APPEND ls_receipt TO gt_gas_receipt.
  ENDLOOP.

  DATA(lv_count) = lines( gt_gas_receipt ).
  MESSAGE s000(ygms_msg) WITH lv_count 'B2B records fetched'.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form MAP_LOCATION_IDS
*& 3.1.3 - Insert GAIL Location IDs against corresponding CTP IDs
*&---------------------------------------------------------------------*
FORM map_location_ids.
  LOOP AT gt_gas_receipt ASSIGNING FIELD-SYMBOL(<fs_receipt>).
    READ TABLE gt_loc_ctp_map INTO DATA(ls_map)
      WITH KEY ongc_ctp_id = <fs_receipt>-ctp_id.
    IF sy-subrc = 0.
      <fs_receipt>-location_id = ls_map-gail_loc_id.
    ENDIF.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form MAP_MATERIAL_NAMES
*& 3.1.4 - Fetch GAIL Material names from YRGA_CST_MAT_MAP
*&---------------------------------------------------------------------*
FORM map_material_names.
  DATA: lt_mat_map TYPE TABLE OF yrga_cst_mat_map.

  DATA: BEGIN OF ls_loc_mat,
          location_id   TYPE ygms_de_loc_id,
          ongc_material TYPE ygms_de_ongc_mat,
        END OF ls_loc_mat,
        lt_loc_mat LIKE TABLE OF ls_loc_mat.

  " Get unique Location ID - ONGC Material combinations
  LOOP AT gt_gas_receipt INTO DATA(ls_receipt).
    ls_loc_mat-location_id   = ls_receipt-location_id.
    ls_loc_mat-ongc_material = ls_receipt-ongc_material.
    COLLECT ls_loc_mat INTO lt_loc_mat.
  ENDLOOP.

  " Fetch material mappings
  IF lt_loc_mat IS NOT INITIAL.
    SELECT * FROM yrga_cst_mat_map
      INTO TABLE lt_mat_map
      FOR ALL ENTRIES IN lt_loc_mat
      WHERE location_id    = lt_loc_mat-location_id
        AND ongc_material  = lt_loc_mat-ongc_material
        AND valid_from    <= gv_date_from
        AND valid_to      >= gv_date_to.
  ENDIF.

  " Map GAIL Material names
  LOOP AT gt_gas_receipt ASSIGNING FIELD-SYMBOL(<fs_receipt>).
    READ TABLE lt_mat_map INTO DATA(ls_mat)
      WITH KEY location_id   = <fs_receipt>-location_id
               ongc_material = <fs_receipt>-ongc_material.
    IF sy-subrc = 0.
      <fs_receipt>-material = ls_mat-gail_material.
    ENDIF.
  ENDLOOP.

  SELECT * INTO TABLE @DATA(it_yrva_cst_pur_mat)
    FROM yrva_cst_pur_mat.
  IF sy-subrc = 0.
    RANGES r_matnr FOR mara-matnr.
    LOOP AT it_yrva_cst_pur_mat INTO DATA(wa_yrva_cst_pur_mat).
      r_matnr-low = wa_yrva_cst_pur_mat-matnr.
      r_matnr-sign = 'I'.
      r_matnr-option = 'EQ'.
      APPEND r_matnr.
    ENDLOOP.
    SORT  gt_gas_receipt BY material.
    DELETE  gt_gas_receipt WHERE material NOT IN r_matnr.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form fetch_data_YRXR098
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM fetch_data_yrxr098 .

  SUBMIT yrvr098_states_qty_report USING SELECTION-SCREEN '1000'
        WITH s_fkdat IN s_date
        WITH p_ex = 'X'
        AND RETURN.

  IMPORT gt_fieldcat FROM  MEMORY ID 'FC'.
  IMPORT it_final FROM  MEMORY ID 'FI'.

  LOOP AT it_final INTO DATA(wa_final).
    MOVE-CORRESPONDING wa_final TO wa_final_main.
    LOOP AT gt_fieldcat INTO DATA(wa_fieldcat) WHERE fieldname CS 'MATNR'.
      REPLACE ALL OCCURRENCES OF 'Qty in MMBTU of' IN wa_fieldcat-seltext_l WITH space.
      CONDENSE wa_fieldcat-seltext_l.
      wa_final_main-matnr = wa_fieldcat-seltext_l.
      ASSIGN COMPONENT wa_fieldcat-fieldname OF STRUCTURE wa_final TO FIELD-SYMBOL(<fs_value>).
      IF sy-subrc = 0.
        wa_final_main-matnr1 = <fs_value>.
      ENDIF.
      APPEND wa_final_main TO it_final_main.
    ENDLOOP.
*append wa_final_main to it_final_main.
  ENDLOOP.


ENDFORM.
