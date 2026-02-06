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
         gail_loc_id  TYPE ygms_de_loc_id,
         ongc_ctp_id  TYPE ygms_de_ongc_ctp,
       END OF ty_loc_ctp_map.

types: begin of ty_final,
         vstel      type vbap-vstel,
         abtnr      type vbkd-abtnr,
         empst      type empst,
         regio      type t001w-regio,
         regio_desc type bezei20,
         address    type char60,
         matnr1     type p decimals 3, "GMS_NG-Z
         matnr2     type p decimals 3, "GMS_NG-NWWI-Z
         matnr3     type p decimals 3, "GMS_NG-NAPM-WOS-Z
         matnr4     type p decimals 3,
         matnr5     type p decimals 3,
         matnr6     type p decimals 3,
         matnr7     type p decimals 3,
         matnr8     type p decimals 3,
         matnr9     type p decimals 3,
         matnr10    type p decimals 3,
         matnr11    type p decimals 3,
         matnr12    type p decimals 3,
         matnr13    type p decimals 3,
         matnr14    type p decimals 3,
         matnr15    type p decimals 3,
       end of ty_final.

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


type-pools : slis.
data: gt_fieldcat   type slis_t_fieldcat_alv with header line,
      it_final      type table of ty_final.

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
   PERFORM fetch_data_YRXR098.

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

SUBMIT YRVR098_STATES_QTY_REPORT Using selection-SCREEN '1000'
      with s_fdate in s_date
      with p_ex = 'X'
      and RETURN.

    import gt_fieldcat from  MEMORY id 'FC'.
    import it_final from  MEMORY id 'FI'.

ENDFORM.
