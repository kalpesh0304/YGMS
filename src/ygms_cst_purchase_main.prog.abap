*&---------------------------------------------------------------------*
*& Report YGMS_CST_PURCHASE_MAIN
*& Description: ONGC CST Purchase Data - Gas Receipt Processing
*& Version: 4.0 - Editable ALV with buttons
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
* Validation ALV structure
TYPES: BEGIN OF ty_validation,
         location_id       TYPE ygms_de_loc_id,
         material          TYPE ygms_de_gail_mat,
         allocated_scm     TYPE p DECIMALS 6,
         allocated_mbg     TYPE p DECIMALS 6,
         ctp_id            TYPE ygms_de_ongc_ctp,
         ongc_material     TYPE ygms_de_ongc_mat,
         supply_scm        TYPE p DECIMALS 6,
         supply_mbg        TYPE p DECIMALS 6,
         diff_pur_sup_scm  TYPE p DECIMALS 6,
         diff_pur_sup_mbg  TYPE p DECIMALS 6,
       END OF ty_validation.
* ALV Display structure
TYPES: BEGIN OF ty_alv_display,
         exclude     TYPE c LENGTH 1,
         state_code  TYPE regio,
         state       TYPE bezei20,
         location_id TYPE ygms_de_loc_id,
         material    TYPE ygms_de_gail_mat,
         total_mbg   TYPE p DECIMALS 3,
         total_scm   TYPE p DECIMALS 3,
         gcv         TYPE ygms_de_gcv,
         ncv         TYPE ygms_de_ncv,
         day01       TYPE p DECIMALS 3,
         day02       TYPE p DECIMALS 3,
         day03       TYPE p DECIMALS 3,
         day04       TYPE p DECIMALS 3,
         day05       TYPE p DECIMALS 3,
         day06       TYPE p DECIMALS 3,
         day07       TYPE p DECIMALS 3,
         day08       TYPE p DECIMALS 3,
         day09       TYPE p DECIMALS 3,
         day10       TYPE p DECIMALS 3,
         day11       TYPE p DECIMALS 3,
         day12       TYPE p DECIMALS 3,
         day13       TYPE p DECIMALS 3,
         day14       TYPE p DECIMALS 3,
         day15       TYPE p DECIMALS 3,
         day16       TYPE p DECIMALS 3,
       END OF ty_alv_display.
TYPES: BEGIN OF ty_final,
         vstel      TYPE vbap-vstel,
         abtnr      TYPE vbkd-abtnr,
         empst      TYPE empst,
         regio      TYPE t001w-regio,
         regio_desc TYPE bezei20,
         address    TYPE char60,
         matnr1     TYPE p DECIMALS 3,
         matnr2     TYPE p DECIMALS 3,
         matnr3     TYPE p DECIMALS 3,
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
         matnr1     TYPE p DECIMALS 3,
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
DATA: gt_alv_display TYPE TABLE OF ty_alv_display,
      gs_alv_display TYPE ty_alv_display.
DATA: gt_validation TYPE TABLE OF ty_validation,
      gs_validation TYPE ty_validation.
DATA: go_container TYPE REF TO cl_gui_custom_container,
      go_grid      TYPE REF TO cl_gui_alv_grid,
      gt_fieldcat  TYPE lvc_t_fcat,
      gs_layout    TYPE lvc_s_layo,
      gt_exclude   TYPE ui_functions.
TYPE-POOLS : slis.
DATA: gt_fieldcat_slis TYPE slis_t_fieldcat_alv WITH HEADER LINE,
      it_final         TYPE TABLE OF ty_final,
      it_final_main    TYPE TABLE OF ty_final1,
      wa_final_main    TYPE ty_final1.
* Flags for Save button visibility and state
DATA: gv_validated    TYPE abap_bool VALUE abap_false,  " Validation done flag
      gv_save_enabled TYPE abap_bool VALUE abap_false,  " Save enabled flag (diff <= 1)
      gv_data_saved   TYPE abap_bool VALUE abap_false.  " Data saved flag - disable editing after save
*----------------------------------------------------------------------*
* Class Definition for ALV Event Handler
*----------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    METHODS: handle_toolbar FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object e_interactive,
      handle_user_command FOR EVENT user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm,
      handle_data_changed FOR EVENT data_changed OF cl_gui_alv_grid
        IMPORTING er_data_changed.
ENDCLASS.
CLASS lcl_event_handler IMPLEMENTATION.
  METHOD handle_toolbar.
    " Toolbar buttons are handled via PF-STATUS 'ZALV_STATUS'
    " This method is kept for potential future ALV grid toolbar customization
  ENDMETHOD.
  METHOD handle_user_command.
    CASE e_ucomm.
      WHEN 'ALLOCATION'.
        PERFORM handle_allocate.
      WHEN 'VALIDATE'.
        PERFORM handle_validate.
      WHEN 'EDIT'.
        PERFORM handle_edit.
      WHEN 'SAVE'.
        PERFORM handle_save.
      WHEN 'RESET'.
        PERFORM handle_reset.
      WHEN 'SEND'.
        PERFORM handle_send.
    ENDCASE.
  ENDMETHOD.
  METHOD handle_data_changed.
    DATA: ls_mod_cell TYPE lvc_s_modi.
    " First apply the changed values to gt_alv_display
    LOOP AT er_data_changed->mt_mod_cells INTO ls_mod_cell.
      READ TABLE gt_alv_display ASSIGNING FIELD-SYMBOL(<fs_row>) INDEX ls_mod_cell-row_id.
      IF sy-subrc = 0.
        ASSIGN COMPONENT ls_mod_cell-fieldname OF STRUCTURE <fs_row> TO FIELD-SYMBOL(<fs_field>).
        IF sy-subrc = 0.
          <fs_field> = ls_mod_cell-value.
        ENDIF.
      ENDIF.
    ENDLOOP.
    " Now recalculate totals
    PERFORM recalculate_totals.
  ENDMETHOD.
ENDCLASS.
DATA: go_event_handler TYPE REF TO lcl_event_handler.
*----------------------------------------------------------------------*
* Initialization
*----------------------------------------------------------------------*
INITIALIZATION.
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
  READ TABLE s_date INTO DATA(ls_date) INDEX 1.
  gv_date_from = ls_date-low.
  gv_date_to   = ls_date-high.
  PERFORM fetch_location_ctp_mappings.
  CHECK gt_loc_ctp_map IS NOT INITIAL.
  PERFORM fetch_b2b_data.
  CHECK gt_gas_receipt IS NOT INITIAL.
  PERFORM map_location_ids.
  PERFORM map_material_names.
  PERFORM fetch_data_yrxr098.
  PERFORM build_alv_display_table.
  PERFORM display_editable_alv.
*&---------------------------------------------------------------------*
*& Form FETCH_LOCATION_CTP_MAPPINGS
*&---------------------------------------------------------------------*
FORM fetch_location_ctp_mappings.
  DATA: lt_loc_map TYPE TABLE OF yrga_cst_loc_map.
  IF s_loc[] IS NOT INITIAL.
    SELECT * FROM yrga_cst_loc_map
      INTO TABLE lt_loc_map
      WHERE gail_loc_id IN s_loc
        AND valid_from <= gv_date_from
        AND valid_to   >= gv_date_to.
  ELSE.
    SELECT * FROM yrga_cst_loc_map
      INTO TABLE lt_loc_map
      WHERE valid_from <= gv_date_from
        AND valid_to   >= gv_date_to.
  ENDIF.
  IF lt_loc_map IS INITIAL.
    MESSAGE s000(ygms_msg) WITH 'No valid Location-CTP mappings found for date range'.
    RETURN.
  ENDIF.
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
*&---------------------------------------------------------------------*
FORM fetch_b2b_data.
  DATA: lt_b2b_data TYPE TABLE OF yrga_cst_b2b_1.
  DATA: c_tgqty TYPE msego2-adqnt,
        i_trqty TYPE msego2-adqnt,
        lv_gcv  TYPE oib_par_fltp,
        lv_ncv  TYPE oib_par_fltp.
  DATA: lt_ctp_ids TYPE TABLE OF ygms_de_ongc_ctp.
  LOOP AT gt_loc_ctp_map INTO DATA(ls_map).
    COLLECT ls_map-ongc_ctp_id INTO lt_ctp_ids.
  ENDLOOP.
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
        i_tguom = 'MBG'
        lv_gcv  = lv_gcv
        lv_ncv  = lv_ncv
      CHANGING
        c_tgqty = c_tgqty.
    ls_receipt-qty_mbg = c_tgqty.
    APPEND ls_receipt TO gt_gas_receipt.
  ENDLOOP.
  DATA(lv_count) = lines( gt_gas_receipt ).
  MESSAGE s000(ygms_msg) WITH lv_count 'B2B records fetched'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form MAP_LOCATION_IDS
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
*&---------------------------------------------------------------------*
FORM map_material_names.
  DATA: lt_mat_map TYPE TABLE OF yrga_cst_mat_map.
  DATA: BEGIN OF ls_loc_mat,
          location_id   TYPE ygms_de_loc_id,
          ongc_material TYPE ygms_de_ongc_mat,
        END OF ls_loc_mat,
        lt_loc_mat LIKE TABLE OF ls_loc_mat.
  LOOP AT gt_gas_receipt INTO DATA(ls_receipt).
    ls_loc_mat-location_id   = ls_receipt-location_id.
    ls_loc_mat-ongc_material = ls_receipt-ongc_material.
    COLLECT ls_loc_mat INTO lt_loc_mat.
  ENDLOOP.
  IF lt_loc_mat IS NOT INITIAL.
    SELECT * FROM yrga_cst_mat_map
      INTO TABLE lt_mat_map
      FOR ALL ENTRIES IN lt_loc_mat
      WHERE location_id    = lt_loc_mat-location_id
        AND ongc_material  = lt_loc_mat-ongc_material
        AND valid_from    <= gv_date_from
        AND valid_to      >= gv_date_to.
  ENDIF.
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
    SORT gt_gas_receipt BY material.
    DELETE gt_gas_receipt WHERE material NOT IN r_matnr.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form FETCH_DATA_YRXR098
*&---------------------------------------------------------------------*
FORM fetch_data_yrxr098.
  SUBMIT yrvr098_states_qty_report USING SELECTION-SCREEN '1000'
        WITH s_fkdat IN s_date
        WITH p_ex = 'X'
        AND RETURN.
  IMPORT gt_fieldcat = gt_fieldcat_slis  FROM MEMORY ID 'FC'.
  IMPORT it_final FROM MEMORY ID 'FI'.
  LOOP AT it_final INTO DATA(wa_final).
    MOVE-CORRESPONDING wa_final TO wa_final_main.
    LOOP AT gt_fieldcat_slis INTO DATA(wa_fieldcat) WHERE fieldname CS 'MATNR'.
      REPLACE ALL OCCURRENCES OF 'Qty in MMBTU of' IN wa_fieldcat-seltext_l WITH space.
      CONDENSE wa_fieldcat-seltext_l.
      wa_final_main-matnr = wa_fieldcat-seltext_l.
      ASSIGN COMPONENT wa_fieldcat-fieldname OF STRUCTURE wa_final TO FIELD-SYMBOL(<fs_value>).
      IF sy-subrc = 0.
        wa_final_main-matnr1 = <fs_value>.
      ENDIF.
      APPEND wa_final_main TO it_final_main.
    ENDLOOP.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form BUILD_ALV_DISPLAY_TABLE
*&---------------------------------------------------------------------*
FORM build_alv_display_table.
  DATA: lt_state_info TYPE TABLE OF t005u,
        ls_alv        TYPE ty_alv_display,
        lv_day_num    TYPE i,
        lv_day_field  TYPE string.
  DATA it_final_temp TYPE TABLE OF ty_final1.
  MOVE it_final_main[] TO it_final_temp[].
  SORT it_final_temp BY matnr.
  DELETE ADJACENT DUPLICATES FROM it_final_temp COMPARING matnr.
  LOOP AT it_final_temp INTO DATA(wa_final_temp).
    READ TABLE it_final_main TRANSPORTING NO FIELDS WITH KEY
      regio = 'GJ' matnr = wa_final_temp-matnr.
    IF sy-subrc <> 0.
      CLEAR wa_final_main.
      wa_final_main-matnr = wa_final_temp-matnr.
      wa_final_main-regio = 'GJ'.
      wa_final_main-regio_desc = 'Gujrat'.
      wa_final_main-empst = wa_final_temp-empst.
      APPEND wa_final_main TO it_final_main.
    ENDIF.
  ENDLOOP.
  LOOP AT it_final_main INTO wa_final_main.
    ls_alv-state_code = wa_final_main-regio.
    ls_alv-state      = wa_final_main-regio_desc.
    ls_alv-material   = wa_final_main-matnr.
    ls_alv-location_id = wa_final_main-empst.
    APPEND ls_alv TO gt_alv_display.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form DISPLAY_EDITABLE_ALV
*&---------------------------------------------------------------------*
FORM display_editable_alv.
  DATA: ls_fieldcat TYPE lvc_s_fcat,
        lv_day      TYPE i,
        lv_fname    TYPE lvc_fname,
        lv_date     TYPE datum,
        lv_date_str TYPE c LENGTH 10.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'EXCLUDE'.
  ls_fieldcat-coltext   = 'Exclude'.
  ls_fieldcat-checkbox  = abap_true.
  ls_fieldcat-edit      = abap_true.
  ls_fieldcat-outputlen = 7.
  APPEND ls_fieldcat TO gt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'STATE_CODE'.
  ls_fieldcat-coltext   = 'State Code'.
  ls_fieldcat-outputlen = 10.
  ls_fieldcat-edit      = abap_false.
  APPEND ls_fieldcat TO gt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'STATE'.
  ls_fieldcat-coltext   = 'State'.
  ls_fieldcat-outputlen = 15.
  ls_fieldcat-edit      = abap_false.
  APPEND ls_fieldcat TO gt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'LOCATION_ID'.
  ls_fieldcat-coltext   = 'Location ID'.
  ls_fieldcat-outputlen = 12.
  ls_fieldcat-edit      = abap_false.
  APPEND ls_fieldcat TO gt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'MATERIAL'.
  ls_fieldcat-coltext   = 'Material'.
  ls_fieldcat-outputlen = 18.
  ls_fieldcat-edit      = abap_false.
  APPEND ls_fieldcat TO gt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'TOTAL_MBG'.
  ls_fieldcat-coltext   = 'Total, MBG'.
  ls_fieldcat-outputlen = 12.
  ls_fieldcat-do_sum    = abap_true.
  ls_fieldcat-edit      = abap_false.
  APPEND ls_fieldcat TO gt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'TOTAL_SCM'.
  ls_fieldcat-coltext   = 'Total, Sm3'.
  ls_fieldcat-outputlen = 12.
  ls_fieldcat-do_sum    = abap_true.
  ls_fieldcat-edit      = abap_false.
  APPEND ls_fieldcat TO gt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'GCV'.
  ls_fieldcat-coltext   = 'Average GCV'.
  ls_fieldcat-outputlen = 12.
  ls_fieldcat-do_sum    = abap_false.
  ls_fieldcat-edit      = abap_false.
  APPEND ls_fieldcat TO gt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'NCV'.
  ls_fieldcat-coltext   = 'Average NCV'.
  ls_fieldcat-outputlen = 12.
  ls_fieldcat-do_sum    = abap_false.
  ls_fieldcat-edit      = abap_false.
  APPEND ls_fieldcat TO gt_fieldcat.
  lv_date = gv_date_from.
  DO 15 TIMES.
    lv_day = sy-index.
    CLEAR ls_fieldcat.
    CASE lv_day.
      WHEN 1.  ls_fieldcat-fieldname = 'DAY01'.
      WHEN 2.  ls_fieldcat-fieldname = 'DAY02'.
      WHEN 3.  ls_fieldcat-fieldname = 'DAY03'.
      WHEN 4.  ls_fieldcat-fieldname = 'DAY04'.
      WHEN 5.  ls_fieldcat-fieldname = 'DAY05'.
      WHEN 6.  ls_fieldcat-fieldname = 'DAY06'.
      WHEN 7.  ls_fieldcat-fieldname = 'DAY07'.
      WHEN 8.  ls_fieldcat-fieldname = 'DAY08'.
      WHEN 9.  ls_fieldcat-fieldname = 'DAY09'.
      WHEN 10. ls_fieldcat-fieldname = 'DAY10'.
      WHEN 11. ls_fieldcat-fieldname = 'DAY11'.
      WHEN 12. ls_fieldcat-fieldname = 'DAY12'.
      WHEN 13. ls_fieldcat-fieldname = 'DAY13'.
      WHEN 14. ls_fieldcat-fieldname = 'DAY14'.
      WHEN 15. ls_fieldcat-fieldname = 'DAY15'.
    ENDCASE.
    WRITE lv_date TO lv_date_str DD/MM/YYYY.
    REPLACE ALL OCCURRENCES OF '/' IN lv_date_str WITH '-'.
    ls_fieldcat-coltext   = lv_date_str.
    ls_fieldcat-outputlen = 12.
    ls_fieldcat-decimals  = 3.           " Match type definition (TYPE p DECIMALS 3)
    ls_fieldcat-edit      = abap_false.  " Not editable initially, enabled via Edit button
    ls_fieldcat-do_sum    = abap_true.
    APPEND ls_fieldcat TO gt_fieldcat.
    lv_date = lv_date + 1.
  ENDDO.
  gs_layout-cwidth_opt = abap_true.
  gs_layout-zebra      = abap_true.
  gs_layout-sel_mode   = 'A'.
  gs_layout-edit       = abap_false.  " Disable grid-level editing, use field catalog for specific fields
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program       = sy-repid
      i_callback_pf_status_set = 'SET_PF_STATUS'
      i_callback_user_command  = 'USER_COMMAND'
      is_layout_lvc            = gs_layout
      it_fieldcat_lvc          = gt_fieldcat
    TABLES
      t_outtab                 = gt_alv_display
    EXCEPTIONS
      program_error            = 1
      OTHERS                   = 2.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form SET_PF_STATUS
*&---------------------------------------------------------------------*
FORM set_pf_status USING rt_extab TYPE slis_t_extab.
  DATA: lr_grid  TYPE REF TO cl_gui_alv_grid,
        ls_extab TYPE slis_extab,
        lt_excl  TYPE slis_t_extab.

  " Copy incoming exclusion table
  lt_excl = rt_extab.

  " Exclude SAVE button if validation not done or save not enabled or data already saved
  IF gv_validated = abap_false OR gv_save_enabled = abap_false OR gv_data_saved = abap_true.
    CLEAR ls_extab.
    ls_extab-fcode = 'SAVE'.
    APPEND ls_extab TO lt_excl.
  ENDIF.

  " Also exclude EDIT button if data already saved
  IF gv_data_saved = abap_true.
    CLEAR ls_extab.
    ls_extab-fcode = 'EDIT'.
    APPEND ls_extab TO lt_excl.
    CLEAR ls_extab.
    ls_extab-fcode = 'ALLOCATION'.
    APPEND ls_extab TO lt_excl.
    CLEAR ls_extab.
    ls_extab-fcode = 'RESET'.
    APPEND ls_extab TO lt_excl.
  ENDIF.

  SET PF-STATUS 'ZALV_STATUS' EXCLUDING lt_excl.

  " Get ALV grid reference and register data_changed event
  CALL FUNCTION 'GET_GLOBALS_FROM_SLVC_FULLSCR'
    IMPORTING
      e_grid = lr_grid.

  IF lr_grid IS BOUND AND go_event_handler IS NOT BOUND.
    CREATE OBJECT go_event_handler.
    SET HANDLER go_event_handler->handle_data_changed FOR lr_grid.
    " Register for edit events
    lr_grid->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_modified ).
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form USER_COMMAND
*&---------------------------------------------------------------------*
FORM user_command USING r_ucomm     TYPE sy-ucomm
                        rs_selfield TYPE slis_selfield.
  DATA: lr_grid TYPE REF TO cl_gui_alv_grid.
  CALL FUNCTION 'GET_GLOBALS_FROM_SLVC_FULLSCR'
    IMPORTING
      e_grid = lr_grid.
  lr_grid->check_changed_data( ).

  " Debug: Show which function code was triggered (can be removed later)
  MESSAGE s000(ygms_msg) WITH 'Function code:' r_ucomm.

  CASE r_ucomm.
    WHEN 'ALLOCATION'.
      PERFORM handle_allocate.
    WHEN 'VALIDATE'.
      PERFORM handle_validate.
    WHEN 'EDIT'.
      PERFORM handle_edit.
    WHEN 'SAVE'.
      PERFORM handle_save.
    WHEN 'RESET'.
      PERFORM handle_reset.
    WHEN 'SEND'.
      PERFORM handle_send.
  ENDCASE.
  rs_selfield-refresh = abap_true.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form HANDLE_ALLOCATE
*&---------------------------------------------------------------------*
FORM handle_allocate.
  TYPES : BEGIN OF ty_sales,
            matnr          TYPE matnr,
            qty_mbg        TYPE p DECIMALS 6,
            qty_mbg_supply TYPE p DECIMALS 6,
            qty_mbg_diff   TYPE p DECIMALS 6,
            qty_allocated  TYPE p DECIMALS 6,
            qty_access     TYPE p DECIMALS 6,
          END OF ty_sales.
  TYPES : BEGIN OF ty_asales,
            regio   TYPE regio,
            qty_mbg TYPE p DECIMALS 6,
          END OF ty_asales.
  DATA l_left TYPE p DECIMALS 6.
  TYPES : BEGIN OF ty_state,
            state_code    TYPE regio,
            state         TYPE bezei20,
            matnr         TYPE matnr,
            qty_mbg       TYPE p DECIMALS 6,
            qty_mbg_diff  TYPE p DECIMALS 6,
            qty_allocated TYPE p DECIMALS 6,
            percentage    TYPE p DECIMALS 6,
          END OF ty_state.
  DATA : it_sales  TYPE TABLE OF ty_sales,
         wa_sales  TYPE ty_sales,
         it_state  TYPE TABLE OF ty_state,
         wa_state  TYPE ty_state,
         it_state1 TYPE TABLE OF ty_state,
         it_asales TYPE TABLE OF ty_asales,
         wa_asales TYPE ty_asales.
  LOOP AT it_final_main INTO wa_final_main.
    wa_asales-qty_mbg = wa_final_main-matnr1.
    wa_asales-regio = wa_final_main-regio.
    COLLECT wa_asales INTO it_asales.
    CLEAR wa_asales.
  ENDLOOP.
  SORT it_asales BY qty_mbg DESCENDING.
  LOOP AT it_final_main INTO wa_final_main.
    IF wa_final_main-regio <> 'GJ'.
      wa_sales-matnr = wa_final_main-matnr.
      wa_sales-qty_mbg = wa_final_main-matnr1.
      COLLECT wa_sales INTO it_sales.
      CLEAR wa_sales.
    ENDIF.
    CLEAR wa_state.
    wa_state-state_code = wa_final_main-regio.
    wa_state-state = wa_final_main-regio_desc.
    wa_state-qty_mbg = wa_final_main-matnr1.
    wa_state-matnr = wa_final_main-matnr.
    COLLECT wa_state INTO it_state.
  ENDLOOP.
  LOOP AT gt_gas_receipt INTO DATA(wa_gas_receipt).
    wa_sales-matnr = wa_gas_receipt-material.
    wa_sales-qty_mbg_supply = wa_gas_receipt-qty_mbg.
    COLLECT wa_sales INTO it_sales.
    CLEAR wa_sales.
  ENDLOOP.
  LOOP AT it_sales ASSIGNING FIELD-SYMBOL(<fs_sales>).
    <fs_sales>-qty_mbg_diff = <fs_sales>-qty_mbg_supply - <fs_sales>-qty_mbg.
  ENDLOOP.
  SORT it_sales BY qty_mbg_diff DESCENDING.
  SORT it_asales BY qty_mbg DESCENDING.
  CLEAR l_left.
  DATA l_exit TYPE flag.
  LOOP AT it_sales ASSIGNING <fs_sales>.
    CLEAR l_exit.
    l_left = <fs_sales>-qty_mbg_diff.
    IF l_left < 0.
      LOOP AT it_asales INTO wa_asales.
        LOOP AT it_state ASSIGNING FIELD-SYMBOL(<fs_state>) WHERE
          matnr = <fs_sales>-matnr AND state_code = wa_asales-regio.
          IF sy-subrc = 0.
            IF <fs_state>-qty_mbg > abs( l_left ).
              <fs_state>-qty_allocated = <fs_state>-qty_mbg + l_left.
              l_exit = 'X'.
              EXIT.
            ELSE.
              l_left = l_left + <fs_state>-qty_mbg.
              CLEAR <fs_state>-qty_allocated.
            ENDIF.
          ENDIF.
        ENDLOOP.
        IF l_exit = 'X'.
          EXIT.
        ENDIF.
      ENDLOOP.
    ELSE.
      READ TABLE it_state ASSIGNING <fs_state> WITH KEY state_code = 'GJ' matnr = <fs_sales>-matnr.
      IF sy-subrc = 0.
        <fs_state>-qty_allocated = l_left + <fs_state>-qty_allocated.
        CLEAR l_left.
      ENDIF.
    ENDIF.
    CLEAR l_left.
  ENDLOOP.
  LOOP AT it_state ASSIGNING <fs_state> WHERE qty_allocated IS INITIAL.
    <fs_state>-qty_allocated = <fs_state>-qty_mbg.
  ENDLOOP.
  MOVE it_state[] TO it_state1[].
  SORT it_state1 BY matnr.
  DELETE ADJACENT DUPLICATES FROM it_state1 COMPARING matnr.
  LOOP AT it_state1 INTO DATA(wa_state1).
    CLEAR l_left.
    LOOP AT it_state INTO wa_state WHERE matnr = wa_state1-matnr.
      l_left = l_left + wa_state-qty_allocated.
    ENDLOOP.
    LOOP AT it_state ASSIGNING <fs_state> WHERE matnr = wa_state1-matnr.
      <fs_state>-percentage = ( <fs_state>-qty_allocated / l_left ) * 100.
    ENDLOOP.
  ENDLOOP.
  DATA l_day TYPE char10.
  DATA l_index(2) TYPE n.
  DATA l_date TYPE sy-datum.
  DATA l_ncv TYPE p DECIMALS 6.
  DATA l_gcv TYPE p DECIMALS 6.
  DATA l_day_sm3 TYPE p DECIMALS 6.
  LOOP AT it_state INTO wa_state WHERE percentage IS NOT INITIAL.
    LOOP AT gt_alv_display ASSIGNING FIELD-SYMBOL(<fs_alv>) WHERE state_code = wa_state-state_code AND
      material = wa_state-matnr.
      CLEAR l_index.
      CLEAR: l_ncv, l_gcv,l_day_sm3.
      l_date = s_date-low.
      DO 15 TIMES.
        l_index = l_index + 1.
        CLEAR l_day.
        CONCATENATE 'DAY' l_index INTO l_day.
        ASSIGN COMPONENT l_day OF STRUCTURE <fs_alv> TO FIELD-SYMBOL(<fs_day>).
        IF sy-subrc = 0.
          READ TABLE gt_gas_receipt INTO wa_gas_receipt WITH KEY
            gas_day = l_date
            material = wa_state-matnr.
          IF sy-subrc = 0.
            <fs_day> = ( wa_gas_receipt-qty_mbg * wa_state-percentage ) / 100.
            <fs_alv>-total_mbg = <fs_alv>-total_mbg + <fs_day>.
            l_day_sm3 = ( wa_gas_receipt-qty_scm * wa_state-percentage ) / 100.
            <fs_alv>-total_scm = <fs_alv>-total_scm + l_day_sm3.
            l_gcv = ( l_day_sm3 * wa_gas_receipt-gcv ) + l_gcv.
            l_ncv = ( l_day_sm3 * wa_gas_receipt-ncv ) + l_ncv.
          ENDIF.
        ENDIF.
        l_date = l_date + 1.
      ENDDO.
      <fs_alv>-gcv = l_gcv / <fs_alv>-total_scm.
      <fs_alv>-ncv = l_ncv / <fs_alv>-total_scm.
      CLEAR l_day_sm3.
    ENDLOOP.
  ENDLOOP.
  MESSAGE s000(ygms_msg) WITH 'Allocate function triggered'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form HANDLE_VALIDATE
*&---------------------------------------------------------------------*
FORM handle_validate.
  DATA: lv_diff_ok  TYPE abap_bool,
        lv_answer   TYPE c LENGTH 1.

  PERFORM build_validation_data.

  " Check if any DIFF_PUR_SUP_MBG > 1
  lv_diff_ok = abap_true.
  LOOP AT gt_validation INTO gs_validation.
    IF abs( gs_validation-diff_pur_sup_mbg ) > 1.
      lv_diff_ok = abap_false.
      EXIT.
    ENDIF.
  ENDLOOP.

  " Set flags
  gv_validated = abap_true.
  gv_save_enabled = lv_diff_ok.

  " Display validation ALV popup
  PERFORM display_validation_alv.

  " Show popup message based on save status using POPUP_TO_INFORM
  IF gv_save_enabled = abap_false.
    CALL FUNCTION 'POPUP_TO_INFORM'
      EXPORTING
        titel = 'Validation FAILED'
        txt1  = 'Difference > 1 MBG found in validation data.'
        txt2  = 'Please adjust the day values and re-validate.'
        txt3  = 'Save button will remain DISABLED.'
        txt4  = ''.
  ELSE.
    CALL FUNCTION 'POPUP_TO_INFORM'
      EXPORTING
        titel = 'Validation PASSED'
        txt1  = 'All differences are within acceptable limit (≤ 1 MBG).'
        txt2  = 'Save button is now ENABLED.'
        txt3  = 'You can proceed to save the data.'
        txt4  = ''.
  ENDIF.

  " Refresh the PF-STATUS to update Save button visibility
  PERFORM refresh_pf_status.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form REFRESH_PF_STATUS
*&---------------------------------------------------------------------*
FORM refresh_pf_status.
  DATA: lt_extab TYPE slis_t_extab,
        ls_extab TYPE slis_extab.

  " Exclude SAVE button if validation not done or save not enabled or data already saved
  IF gv_validated = abap_false OR gv_save_enabled = abap_false OR gv_data_saved = abap_true.
    CLEAR ls_extab.
    ls_extab-fcode = 'SAVE'.
    APPEND ls_extab TO lt_extab.
  ENDIF.

  " Also exclude EDIT, ALLOCATION, RESET buttons if data already saved
  IF gv_data_saved = abap_true.
    CLEAR ls_extab.
    ls_extab-fcode = 'EDIT'.
    APPEND ls_extab TO lt_extab.
    CLEAR ls_extab.
    ls_extab-fcode = 'ALLOCATION'.
    APPEND ls_extab TO lt_extab.
    CLEAR ls_extab.
    ls_extab-fcode = 'RESET'.
    APPEND ls_extab TO lt_extab.
  ENDIF.

  SET PF-STATUS 'ZALV_STATUS' EXCLUDING lt_extab.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form BUILD_VALIDATION_DATA
*&---------------------------------------------------------------------*
FORM build_validation_data.
  DATA: ls_validation TYPE ty_validation.
  CLEAR gt_validation.
  DATA: BEGIN OF ls_key,
          location_id TYPE ygms_de_loc_id,
          material    TYPE ygms_de_gail_mat,
        END OF ls_key,
        lt_keys LIKE TABLE OF ls_key.
  LOOP AT gt_alv_display INTO gs_alv_display WHERE exclude IS INITIAL.
    ls_key-location_id = gs_alv_display-location_id.
    ls_key-material    = gs_alv_display-material.
    COLLECT ls_key INTO lt_keys.
  ENDLOOP.
  LOOP AT lt_keys INTO ls_key.
    CLEAR ls_validation.
    ls_validation-location_id = ls_key-location_id.
    ls_validation-material    = ls_key-material.
    LOOP AT gt_alv_display INTO gs_alv_display
      WHERE location_id = ls_key-location_id
        AND material    = ls_key-material
        AND exclude     IS INITIAL.
      ls_validation-allocated_scm = ls_validation-allocated_scm + gs_alv_display-total_scm.
      ls_validation-allocated_mbg = ls_validation-allocated_mbg + gs_alv_display-total_mbg.
    ENDLOOP.
    READ TABLE gt_gas_receipt INTO DATA(ls_receipt)
      WITH KEY location_id = ls_key-location_id
               material    = ls_key-material.
    IF sy-subrc = 0.
      ls_validation-ctp_id        = ls_receipt-ctp_id.
      ls_validation-ongc_material = ls_receipt-ongc_material.
    ENDIF.
    LOOP AT gt_gas_receipt INTO ls_receipt
      WHERE location_id = ls_key-location_id
        AND material    = ls_key-material.
      ls_validation-supply_scm = ls_validation-supply_scm + ls_receipt-qty_scm.
      ls_validation-supply_mbg = ls_validation-supply_mbg + ls_receipt-qty_mbg.
    ENDLOOP.
    ls_validation-diff_pur_sup_scm = ls_validation-allocated_scm - ls_validation-supply_scm.
    ls_validation-diff_pur_sup_mbg = ls_validation-allocated_mbg - ls_validation-supply_mbg.
    APPEND ls_validation TO gt_validation.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form DISPLAY_VALIDATION_ALV
*&---------------------------------------------------------------------*
FORM display_validation_alv.
  DATA: lt_fieldcat TYPE slis_t_fieldcat_alv,
        ls_fieldcat TYPE slis_fieldcat_alv,
        ls_layout   TYPE slis_layout_alv.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'LOCATION_ID'.
  ls_fieldcat-seltext_l = 'Location ID'.
  ls_fieldcat-col_pos   = 1.
  APPEND ls_fieldcat TO lt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'MATERIAL'.
  ls_fieldcat-seltext_l = 'Material'.
  ls_fieldcat-col_pos   = 2.
  APPEND ls_fieldcat TO lt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'ALLOCATED_SCM'.
  ls_fieldcat-seltext_l = 'Allocated Sm³'.
  ls_fieldcat-col_pos   = 3.
  ls_fieldcat-do_sum    = abap_true.
  APPEND ls_fieldcat TO lt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'ALLOCATED_MBG'.
  ls_fieldcat-seltext_l = 'Allocated MBG'.
  ls_fieldcat-col_pos   = 4.
  ls_fieldcat-do_sum    = abap_true.
  APPEND ls_fieldcat TO lt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'CTP_ID'.
  ls_fieldcat-seltext_l = 'CTP ID'.
  ls_fieldcat-col_pos   = 5.
  APPEND ls_fieldcat TO lt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'ONGC_MATERIAL'.
  ls_fieldcat-seltext_l = 'ONGC Material'.
  ls_fieldcat-col_pos   = 6.
  APPEND ls_fieldcat TO lt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'SUPPLY_SCM'.
  ls_fieldcat-seltext_l = 'Supply Sm³'.
  ls_fieldcat-col_pos   = 7.
  ls_fieldcat-do_sum    = abap_true.
  APPEND ls_fieldcat TO lt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'SUPPLY_MBG'.
  ls_fieldcat-seltext_l = 'Supply MBG'.
  ls_fieldcat-col_pos   = 8.
  ls_fieldcat-do_sum    = abap_true.
  APPEND ls_fieldcat TO lt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'DIFF_PUR_SUP_SCM'.
  ls_fieldcat-seltext_l = 'Diff. Pur vs Supply Sm³'.
  ls_fieldcat-col_pos   = 9.
  ls_fieldcat-do_sum    = abap_true.
  APPEND ls_fieldcat TO lt_fieldcat.
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'DIFF_PUR_SUP_MBG'.
  ls_fieldcat-seltext_l = 'Diff. Pur vs Supply MBG'.
  ls_fieldcat-col_pos   = 10.
  ls_fieldcat-do_sum    = abap_true.
  APPEND ls_fieldcat TO lt_fieldcat.
  ls_layout-colwidth_optimize = abap_true.
  ls_layout-zebra             = abap_true.
  CALL FUNCTION 'REUSE_ALV_POPUP_TO_SELECT'
    EXPORTING
      i_title               = 'Validation Results'
      i_selection           = ' '
      i_zebra               = abap_true
      i_screen_start_column = 5
      i_screen_start_line   = 5
      i_screen_end_column   = 150
      i_screen_end_line     = 25
      i_tabname             = 'GT_VALIDATION'
      it_fieldcat           = lt_fieldcat
    TABLES
      t_outtab              = gt_validation
    EXCEPTIONS
      program_error         = 1
      OTHERS                = 2.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form HANDLE_EDIT
*&---------------------------------------------------------------------*
FORM handle_edit.
  DATA: lr_grid        TYPE REF TO cl_gui_alv_grid,
        lt_fcat        TYPE lvc_t_fcat,
        ls_fcat        TYPE lvc_s_fcat,
        lv_day_edit    TYPE abap_bool,
        lv_new_day_edit TYPE abap_bool,
        lv_new_excl_edit TYPE abap_bool.

  " Get ALV grid reference
  CALL FUNCTION 'GET_GLOBALS_FROM_SLVC_FULLSCR'
    IMPORTING
      e_grid = lr_grid.

  " Get current field catalog
  lr_grid->get_frontend_fieldcatalog( IMPORTING et_fieldcatalog = lt_fcat ).

  " Check current edit state of DAY01 field
  READ TABLE lt_fcat INTO ls_fcat WITH KEY fieldname = 'DAY01'.
  IF sy-subrc = 0.
    lv_day_edit = ls_fcat-edit.
  ENDIF.

  " Toggle: if DAY is editable, disable it and enable EXCLUDE; otherwise vice versa
  IF lv_day_edit = abap_true.
    lv_new_day_edit = abap_false.
    lv_new_excl_edit = abap_true.
  ELSE.
    lv_new_day_edit = abap_true.
    lv_new_excl_edit = abap_false.
  ENDIF.

  " Apply toggle to field catalog
  LOOP AT lt_fcat ASSIGNING FIELD-SYMBOL(<fs_fcat>).
    IF <fs_fcat>-fieldname CP 'DAY*'.
      <fs_fcat>-edit = lv_new_day_edit.
    ELSEIF <fs_fcat>-fieldname = 'EXCLUDE'.
      <fs_fcat>-edit = lv_new_excl_edit.
    ENDIF.
  ENDLOOP.

  " Set updated field catalog
  lr_grid->set_frontend_fieldcatalog( EXPORTING it_fieldcatalog = lt_fcat ).

  " Refresh the ALV
  lr_grid->refresh_table_display( ).

  " Display appropriate message based on new state
  IF lv_new_day_edit = abap_true.
    MESSAGE s000(ygms_msg) WITH 'Edit mode enabled - Day columns are now editable'.
  ELSE.
    MESSAGE s000(ygms_msg) WITH 'Edit mode disabled - Exclude checkbox is now editable'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form HANDLE_SAVE
*&---------------------------------------------------------------------*
FORM handle_save.
  DATA: lv_answer TYPE c LENGTH 1.

  " Confirm with user before saving using POPUP_TO_CONFIRM_STEP
  CALL FUNCTION 'POPUP_TO_CONFIRM_STEP'
    EXPORTING
      textline1   = 'Do you want to save the data to database?'
      titel       = 'Confirm Save'
      cancel_display = ' '
    IMPORTING
      answer      = lv_answer.

  IF lv_answer = 'J'.  " User clicked Yes (J = Ja/Yes)
    " Save data to database
    PERFORM save_data_to_db.

    " Set data saved flag
    gv_data_saved = abap_true.

    " Disable all fields in ALV
    PERFORM disable_all_fields.

    " Refresh PF-STATUS to hide Save, Edit, Allocation, Reset buttons
    PERFORM refresh_pf_status.

    " Show success message
    CALL FUNCTION 'POPUP_TO_INFORM'
      EXPORTING
        titel = 'Save Successful'
        txt1  = 'Data has been saved successfully to the database.'
        txt2  = 'All fields are now in display mode.'
        txt3  = ''
        txt4  = ''.
  ELSE.
    " User clicked No - just return without saving
    MESSAGE s000(ygms_msg) WITH 'Save operation cancelled by user'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form SAVE_DATA_TO_DB
*&---------------------------------------------------------------------*
FORM save_data_to_db.
  " Type for GAIL ID mapping
  TYPES: BEGIN OF ty_gail_id_map,
           location_id TYPE ygms_de_loc_id,
           material    TYPE ygms_de_gail_mat,
           state_code  TYPE regio,
           gail_id     TYPE c LENGTH 14,
         END OF ty_gail_id_map.

  " Type for error log
  TYPES: BEGIN OF ty_error_log,
           date_from   TYPE datum,
           date_to     TYPE datum,
           location_id TYPE ygms_de_loc_id,
           material    TYPE ygms_de_gail_mat,
           state_code  TYPE regio,
           gail_ids    TYPE string,
         END OF ty_error_log.

  DATA: lt_cst_pur      TYPE TABLE OF yrga_cst_pur,
        ls_cst_pur      TYPE yrga_cst_pur,
        lt_cst_fnt      TYPE TABLE OF yrga_cst_fnt_d,
        ls_cst_fnt      TYPE yrga_cst_fnt_d,
        lv_timestamp    TYPE timestampl,
        lv_ts_char      TYPE c LENGTH 14,
        lv_date         TYPE datum,
        lv_day_index    TYPE i,
        lv_day_qty      TYPE p DECIMALS 6,
        lv_counter      TYPE i,
        lv_fnt_counter  TYPE i,
        lt_gail_id_map  TYPE TABLE OF ty_gail_id_map,
        ls_gail_id_map  TYPE ty_gail_id_map,
        lv_gail_prefix  TYPE c LENGTH 8,
        lv_fortnight    TYPE c LENGTH 2,
        lv_seq_number   TYPE n LENGTH 6,
        lv_return_code  TYPE inri-returncode,
        lt_error_log    TYPE TABLE OF ty_error_log,
        ls_error_log    TYPE ty_error_log,
        lv_error_found  TYPE abap_bool.

  " Variables for weighted average calculation
  DATA: lv_total_vol    TYPE p DECIMALS 6,
        lv_sum_vol_gcv  TYPE p DECIMALS 6,
        lv_sum_vol_ncv  TYPE p DECIMALS 6,
        lv_avg_gcv      TYPE ygms_de_gcv,
        lv_avg_ncv      TYPE ygms_de_ncv,
        lv_total_mbg    TYPE p DECIMALS 6,
        lv_total_scm    TYPE p DECIMALS 6.

  " Variables for GAIL ID validation
  DATA: lt_gail_ids     TYPE TABLE OF yrga_cst_pur-gail_id,
        lv_gail_count   TYPE i,
        lv_gail_id_str  TYPE string.

  " Get current timestamp
  GET TIME STAMP FIELD lv_timestamp.
  lv_ts_char = lv_timestamp.

  " Generate GAIL_ID prefix: GA + YYMM + F1/F2
  DATA(lv_day) = gv_date_from+6(2).
  IF lv_day <= 15.
    lv_fortnight = 'F1'.
  ELSE.
    lv_fortnight = 'F2'.
  ENDIF.

  " Build prefix: GA + YY + MM + F1/F2 (e.g., GA2510F1)
  CONCATENATE 'GA' gv_date_from+2(2) gv_date_from+4(2) lv_fortnight INTO lv_gail_prefix.

  " Initialize error flag
  lv_error_found = abap_false.

  " First pass: Generate unique GAIL_IDs for each Location-Material-State combination
  LOOP AT gt_alv_display INTO gs_alv_display WHERE exclude IS INITIAL.
    READ TABLE lt_gail_id_map INTO ls_gail_id_map
      WITH KEY location_id = gs_alv_display-location_id
               material    = gs_alv_display-material
               state_code  = gs_alv_display-state_code.
    IF sy-subrc <> 0.
      " Get next number from number range
      CALL FUNCTION 'NUMBER_GET_NEXT'
        EXPORTING
          nr_range_nr = '01'
          object      = 'ZCST'
        IMPORTING
          number      = lv_seq_number
          returncode  = lv_return_code.

      IF lv_return_code IS INITIAL OR lv_return_code = '1'.
        CLEAR ls_gail_id_map.
        ls_gail_id_map-location_id = gs_alv_display-location_id.
        ls_gail_id_map-material    = gs_alv_display-material.
        ls_gail_id_map-state_code  = gs_alv_display-state_code.
        CONCATENATE lv_gail_prefix lv_seq_number INTO ls_gail_id_map-gail_id.
        APPEND ls_gail_id_map TO lt_gail_id_map.
      ENDIF.
    ENDIF.
  ENDLOOP.

  " Second pass: Create daily records for YRGA_CST_PUR
  LOOP AT gt_alv_display INTO gs_alv_display WHERE exclude IS INITIAL.
    READ TABLE lt_gail_id_map INTO ls_gail_id_map
      WITH KEY location_id = gs_alv_display-location_id
               material    = gs_alv_display-material
               state_code  = gs_alv_display-state_code.

    lv_date = gv_date_from.

    DO 15 TIMES.
      lv_day_index = sy-index.

      CASE lv_day_index.
        WHEN 1.  lv_day_qty = gs_alv_display-day01.
        WHEN 2.  lv_day_qty = gs_alv_display-day02.
        WHEN 3.  lv_day_qty = gs_alv_display-day03.
        WHEN 4.  lv_day_qty = gs_alv_display-day04.
        WHEN 5.  lv_day_qty = gs_alv_display-day05.
        WHEN 6.  lv_day_qty = gs_alv_display-day06.
        WHEN 7.  lv_day_qty = gs_alv_display-day07.
        WHEN 8.  lv_day_qty = gs_alv_display-day08.
        WHEN 9.  lv_day_qty = gs_alv_display-day09.
        WHEN 10. lv_day_qty = gs_alv_display-day10.
        WHEN 11. lv_day_qty = gs_alv_display-day11.
        WHEN 12. lv_day_qty = gs_alv_display-day12.
        WHEN 13. lv_day_qty = gs_alv_display-day13.
        WHEN 14. lv_day_qty = gs_alv_display-day14.
        WHEN 15. lv_day_qty = gs_alv_display-day15.
      ENDCASE.

      IF lv_day_qty > 0.
        CLEAR ls_cst_pur.

        ls_cst_pur-gas_day      = lv_date.
        ls_cst_pur-location     = gs_alv_display-location_id.
        ls_cst_pur-material     = gs_alv_display-material.
        ls_cst_pur-state_code   = gs_alv_display-state_code.
        ls_cst_pur-state        = gs_alv_display-state.

        " Get CTP and ONGC material from gas receipt
        READ TABLE gt_gas_receipt INTO DATA(ls_receipt)
          WITH KEY location_id = gs_alv_display-location_id
                   material    = gs_alv_display-material
                   gas_day     = lv_date.
        IF sy-subrc = 0.
          ls_cst_pur-ctp         = ls_receipt-ctp_id.
          ls_cst_pur-ongc_mater  = ls_receipt-ongc_material.
          ls_cst_pur-ongc_id     = ls_receipt-ongc_id.
        ELSE.
          READ TABLE gt_gas_receipt INTO ls_receipt
            WITH KEY location_id = gs_alv_display-location_id
                     material    = gs_alv_display-material.
          IF sy-subrc = 0.
            ls_cst_pur-ctp         = ls_receipt-ctp_id.
            ls_cst_pur-ongc_mater  = ls_receipt-ongc_material.
            ls_cst_pur-ongc_id     = ls_receipt-ongc_id.
          ENDIF.
        ENDIF.

        ls_cst_pur-time_stamp   = lv_ts_char.
        ls_cst_pur-qty_in_mbg   = lv_day_qty.
        ls_cst_pur-gcv          = gs_alv_display-gcv.
        ls_cst_pur-ncv          = gs_alv_display-ncv.

        " Calculate SCM for this day's quantity
        DATA: c_tgqty TYPE msego2-adqnt,
              i_trqty TYPE msego2-adqnt,
              lv_gcv  TYPE oib_par_fltp,
              lv_ncv  TYPE oib_par_fltp.
        IF gs_alv_display-gcv > 0.
          CLEAR c_tgqty.
          i_trqty = lv_day_qty.
          lv_gcv  = gs_alv_display-gcv.
          lv_ncv  = gs_alv_display-ncv.
          CALL FUNCTION 'YRX_QTY_UOM_TO_QTY_UOM'
            EXPORTING
              i_trqty = i_trqty
              i_truom = 'MBG'
              i_tguom = 'SM3'
              lv_gcv  = lv_gcv
              lv_ncv  = lv_ncv
            CHANGING
              c_tgqty = c_tgqty.
          ls_cst_pur-qty_in_scm = c_tgqty.
        ENDIF.

        ls_cst_pur-gail_id      = ls_gail_id_map-gail_id.
        ls_cst_pur-exclude      = gs_alv_display-exclude.
        ls_cst_pur-created_by   = sy-uname.
        ls_cst_pur-created_date = sy-datum.
        ls_cst_pur-created_time = sy-uzeit.

        APPEND ls_cst_pur TO lt_cst_pur.
      ENDIF.

      lv_date = lv_date + 1.
    ENDDO.
  ENDLOOP.

  " Third pass: Create fortnightly aggregated records for YRGA_CST_FNT_D
  " Calculate weighted average GCV/NCV: Σ(Volume × GCV/NCV) / Total Volume
  LOOP AT lt_gail_id_map INTO ls_gail_id_map.
    CLEAR: lv_total_vol, lv_sum_vol_gcv, lv_sum_vol_ncv, lv_total_mbg, lv_total_scm.
    CLEAR ls_cst_fnt.

    " Sum quantities and calculate weighted averages for this Location-Material-State
    LOOP AT lt_cst_pur INTO ls_cst_pur
      WHERE location     = ls_gail_id_map-location_id
        AND material     = ls_gail_id_map-material
        AND state_code   = ls_gail_id_map-state_code.

      " Accumulate totals
      lv_total_mbg = lv_total_mbg + ls_cst_pur-qty_in_mbg.
      lv_total_scm = lv_total_scm + ls_cst_pur-qty_in_scm.

      " For weighted average: Σ(Volume × GCV) and Σ(Volume × NCV)
      lv_sum_vol_gcv = lv_sum_vol_gcv + ( ls_cst_pur-qty_in_scm * ls_cst_pur-gcv ).
      lv_sum_vol_ncv = lv_sum_vol_ncv + ( ls_cst_pur-qty_in_scm * ls_cst_pur-ncv ).
      lv_total_vol   = lv_total_vol + ls_cst_pur-qty_in_scm.

      " Get CTP and ONGC material (from first record)
      IF ls_cst_fnt-ctp IS INITIAL.
        ls_cst_fnt-ctp        = ls_cst_pur-ctp.
        ls_cst_fnt-ongc_mater = ls_cst_pur-ongc_mater.
        ls_cst_fnt-state      = ls_cst_pur-state.
      ENDIF.
    ENDLOOP.

    " Calculate weighted average GCV/NCV
    IF lv_total_vol > 0.
      lv_avg_gcv = lv_sum_vol_gcv / lv_total_vol.
      lv_avg_ncv = lv_sum_vol_ncv / lv_total_vol.
    ENDIF.

    " Populate fortnightly record
    ls_cst_fnt-date_from    = gv_date_from.
    ls_cst_fnt-date_to      = gv_date_to.
    ls_cst_fnt-location     = ls_gail_id_map-location_id.
    ls_cst_fnt-material     = ls_gail_id_map-material.
    ls_cst_fnt-state_code   = ls_gail_id_map-state_code.
    ls_cst_fnt-time_stamp   = lv_ts_char.
    ls_cst_fnt-qty_in_mbg   = lv_total_mbg.
    ls_cst_fnt-gcv          = lv_avg_gcv.
    ls_cst_fnt-ncv          = lv_avg_ncv.
    ls_cst_fnt-qty_in_scm   = lv_total_scm.
    ls_cst_fnt-gail_id      = ls_gail_id_map-gail_id.
    ls_cst_fnt-created_by   = sy-uname.
    ls_cst_fnt-created_date = sy-datum.
    ls_cst_fnt-created_time = sy-uzeit.

    APPEND ls_cst_fnt TO lt_cst_fnt.
  ENDLOOP.

  " Check for duplicate GAIL IDs (validation step c)
  " For each Location-Material-State, check if GAIL ID already exists in YRGA_CST_PUR
  LOOP AT lt_gail_id_map INTO ls_gail_id_map.
    CLEAR: lt_gail_ids, lv_gail_count, lv_gail_id_str.

    " Check if GAIL IDs already exist for this combination in the date range
    SELECT DISTINCT gail_id FROM yrga_cst_pur
      INTO TABLE lt_gail_ids
      WHERE location    = ls_gail_id_map-location_id
        AND material    = ls_gail_id_map-material
        AND state_code  = ls_gail_id_map-state_code
        AND gas_day    BETWEEN gv_date_from AND gv_date_to.

    lv_gail_count = lines( lt_gail_ids ).

    IF lv_gail_count > 1.
      " Multiple GAIL IDs found - log error
      lv_error_found = abap_true.
      CLEAR ls_error_log.
      ls_error_log-date_from   = gv_date_from.
      ls_error_log-date_to     = gv_date_to.
      ls_error_log-location_id = ls_gail_id_map-location_id.
      ls_error_log-material    = ls_gail_id_map-material.
      ls_error_log-state_code  = ls_gail_id_map-state_code.

      " Build GAIL IDs string for error message
      LOOP AT lt_gail_ids INTO DATA(lv_gail_id).
        IF lv_gail_id_str IS INITIAL.
          lv_gail_id_str = lv_gail_id.
        ELSE.
          CONCATENATE lv_gail_id_str ',' lv_gail_id INTO lv_gail_id_str SEPARATED BY space.
        ENDIF.
      ENDLOOP.
      ls_error_log-gail_ids = lv_gail_id_str.
      APPEND ls_error_log TO lt_error_log.
    ENDIF.
  ENDLOOP.

  " If errors found, display error log and exit without saving
  IF lv_error_found = abap_true.
    PERFORM display_gail_id_error_log USING lt_error_log.
    MESSAGE e000(ygms_msg) WITH 'Multiple GAIL IDs found. Data NOT saved.'.
    RETURN.
  ENDIF.

  " Delete existing data for same Location ID and Fortnight (step f)
  DELETE FROM yrga_cst_pur
    WHERE gas_day BETWEEN gv_date_from AND gv_date_to.

  DELETE FROM yrga_cst_fnt_d
    WHERE date_from = gv_date_from
      AND date_to   = gv_date_to.

  " Save records to both database tables
  IF lt_cst_pur IS NOT INITIAL.
    MODIFY yrga_cst_pur FROM TABLE lt_cst_pur.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      MESSAGE e000(ygms_msg) WITH 'Error saving data to YRGA_CST_PUR'.
      RETURN.
    ENDIF.
  ENDIF.

  IF lt_cst_fnt IS NOT INITIAL.
    MODIFY yrga_cst_fnt_d FROM TABLE lt_cst_fnt.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      MESSAGE e000(ygms_msg) WITH 'Error saving data to YRGA_CST_FNT_D'.
      RETURN.
    ENDIF.
  ENDIF.

  " Commit if both saves successful
  COMMIT WORK AND WAIT.

  lv_counter = lines( lt_cst_pur ).
  lv_fnt_counter = lines( lt_cst_fnt ).
  MESSAGE s000(ygms_msg) WITH lv_counter 'daily,' lv_fnt_counter 'fortnightly records saved'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form DISPLAY_GAIL_ID_ERROR_LOG
*&---------------------------------------------------------------------*
FORM display_gail_id_error_log USING pt_error_log TYPE STANDARD TABLE.
  DATA: lt_fieldcat TYPE slis_t_fieldcat_alv,
        ls_fieldcat TYPE slis_fieldcat_alv.

  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'DATE_FROM'.
  ls_fieldcat-seltext_l = 'From Date'.
  ls_fieldcat-col_pos   = 1.
  APPEND ls_fieldcat TO lt_fieldcat.

  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'DATE_TO'.
  ls_fieldcat-seltext_l = 'To Date'.
  ls_fieldcat-col_pos   = 2.
  APPEND ls_fieldcat TO lt_fieldcat.

  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'LOCATION_ID'.
  ls_fieldcat-seltext_l = 'Location ID'.
  ls_fieldcat-col_pos   = 3.
  APPEND ls_fieldcat TO lt_fieldcat.

  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'MATERIAL'.
  ls_fieldcat-seltext_l = 'Material'.
  ls_fieldcat-col_pos   = 4.
  APPEND ls_fieldcat TO lt_fieldcat.

  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'STATE_CODE'.
  ls_fieldcat-seltext_l = 'State Code'.
  ls_fieldcat-col_pos   = 5.
  APPEND ls_fieldcat TO lt_fieldcat.

  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'GAIL_IDS'.
  ls_fieldcat-seltext_l = 'GAIL IDs Found'.
  ls_fieldcat-col_pos   = 6.
  ls_fieldcat-outputlen = 50.
  APPEND ls_fieldcat TO lt_fieldcat.

  CALL FUNCTION 'REUSE_ALV_POPUP_TO_SELECT'
    EXPORTING
      i_title               = 'Error: Multiple GAIL IDs Found'
      i_selection           = ' '
      i_zebra               = abap_true
      i_screen_start_column = 5
      i_screen_start_line   = 5
      i_screen_end_column   = 130
      i_screen_end_line     = 20
      i_tabname             = 'PT_ERROR_LOG'
      it_fieldcat           = lt_fieldcat
    TABLES
      t_outtab              = pt_error_log
    EXCEPTIONS
      program_error         = 1
      OTHERS                = 2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form DISABLE_ALL_FIELDS
*&---------------------------------------------------------------------*
FORM disable_all_fields.
  DATA: lr_grid TYPE REF TO cl_gui_alv_grid,
        lt_fcat TYPE lvc_t_fcat.

  " Get ALV grid reference
  CALL FUNCTION 'GET_GLOBALS_FROM_SLVC_FULLSCR'
    IMPORTING
      e_grid = lr_grid.

  IF lr_grid IS NOT BOUND.
    RETURN.
  ENDIF.

  " Get current field catalog
  lr_grid->get_frontend_fieldcatalog( IMPORTING et_fieldcatalog = lt_fcat ).

  " Disable editing for all fields
  LOOP AT lt_fcat ASSIGNING FIELD-SYMBOL(<fs_fcat>).
    <fs_fcat>-edit = abap_false.
  ENDLOOP.

  " Set updated field catalog
  lr_grid->set_frontend_fieldcatalog( EXPORTING it_fieldcatalog = lt_fcat ).

  " Refresh the ALV
  lr_grid->refresh_table_display( ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form HANDLE_RESET
*&---------------------------------------------------------------------*
FORM handle_reset.
  CLEAR gt_alv_display.
  PERFORM build_alv_display_table.
  MESSAGE s000(ygms_msg) WITH 'Data reset to original values'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form HANDLE_SEND
*&---------------------------------------------------------------------*
FORM handle_send.
  MESSAGE s000(ygms_msg) WITH 'Send function triggered'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form RECALCULATE_TOTALS
*&---------------------------------------------------------------------*
FORM recalculate_totals.
  DATA: lr_grid TYPE REF TO cl_gui_alv_grid,
        c_tgqty TYPE msego2-adqnt,
        i_trqty TYPE msego2-adqnt,
        lv_gcv  TYPE oib_par_fltp,
        lv_ncv  TYPE oib_par_fltp.

  CALL FUNCTION 'GET_GLOBALS_FROM_SLVC_FULLSCR'
    IMPORTING
      e_grid = lr_grid.

  " Recalculate totals for each row (only TOTAL_MBG and TOTAL_SCM - GCV/NCV unchanged)
  LOOP AT gt_alv_display ASSIGNING FIELD-SYMBOL(<fs_alv>).
    " Sum all day columns for TOTAL_MBG
    <fs_alv>-total_mbg = <fs_alv>-day01 + <fs_alv>-day02 + <fs_alv>-day03 +
                         <fs_alv>-day04 + <fs_alv>-day05 + <fs_alv>-day06 +
                         <fs_alv>-day07 + <fs_alv>-day08 + <fs_alv>-day09 +
                         <fs_alv>-day10 + <fs_alv>-day11 + <fs_alv>-day12 +
                         <fs_alv>-day13 + <fs_alv>-day14 + <fs_alv>-day15.

    " Convert TOTAL_MBG to TOTAL_SCM using existing GCV/NCV values (no gt_gas_receipt)
    IF <fs_alv>-gcv > 0 AND <fs_alv>-total_mbg > 0.
      CLEAR c_tgqty.
      i_trqty = <fs_alv>-total_mbg.
      lv_gcv  = <fs_alv>-gcv.
      lv_ncv  = <fs_alv>-ncv.
      CALL FUNCTION 'YRX_QTY_UOM_TO_QTY_UOM'
        EXPORTING
          i_trqty = i_trqty
          i_truom = 'MBG'
          i_tguom = 'SM3'
          lv_gcv  = lv_gcv
          lv_ncv  = lv_ncv
        CHANGING
          c_tgqty = c_tgqty.
      <fs_alv>-total_scm = c_tgqty.
    ELSE.
      <fs_alv>-total_scm = 0.
    ENDIF.
    " GCV and NCV remain unchanged (already set during allocation)
  ENDLOOP.

  " Refresh ALV display
  IF lr_grid IS BOUND.
    lr_grid->refresh_table_display( ).
  ENDIF.
ENDFORM.
