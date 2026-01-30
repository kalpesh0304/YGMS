INTERFACE ygms_if_cst_constants
  PUBLIC.

  "! <p class="shorttext synchronized" lang="en">Tax Types</p>
  CONSTANTS:
    BEGIN OF gc_tax_type,
      cst TYPE char3 VALUE 'CST',
      gst TYPE char3 VALUE 'GST',
    END OF gc_tax_type.

  "! <p class="shorttext synchronized" lang="en">Operations</p>
  CONSTANTS:
    BEGIN OF gc_operation,
      insert TYPE char1 VALUE 'I',
      update TYPE char1 VALUE 'U',
      delete TYPE char1 VALUE 'D',
    END OF gc_operation.

  "! <p class="shorttext synchronized" lang="en">Status Values</p>
  CONSTANTS:
    BEGIN OF gc_status,
      active   TYPE char1 VALUE 'A',
      inactive TYPE char1 VALUE 'I',
      pending  TYPE char1 VALUE 'P',
      sent     TYPE char1 VALUE 'S',
      error    TYPE char1 VALUE 'E',
    END OF gc_status.

  "! <p class="shorttext synchronized" lang="en">Activity Types for Authorization</p>
  CONSTANTS:
    BEGIN OF gc_activity,
      create  TYPE activ_auth VALUE '01',
      change  TYPE activ_auth VALUE '02',
      display TYPE activ_auth VALUE '03',
    END OF gc_activity.

  "! <p class="shorttext synchronized" lang="en">Table Names</p>
  CONSTANTS:
    BEGIN OF gc_tables,
      loc_map   TYPE tabname VALUE 'YGMS_CST_LOC_MAP',
      mat_map   TYPE tabname VALUE 'YGMS_CST_MAT_MAP',
      b2b_1     TYPE tabname VALUE 'YGMS_CST_B2B_1',
      purchase  TYPE tabname VALUE 'YGMS_CST_PUR',
      fnt_data  TYPE tabname VALUE 'YGMS_FNT_DATA',
      audit_log TYPE tabname VALUE 'YGMS_AUDIT_LOG',
    END OF gc_tables.

  "! <p class="shorttext synchronized" lang="en">Authorization Objects</p>
  CONSTANTS:
    BEGIN OF gc_auth_object,
      location TYPE xuobject VALUE 'YGMS_LOC',
      state    TYPE xuobject VALUE 'YGMS_STATE',
    END OF gc_auth_object.

  "! <p class="shorttext synchronized" lang="en">Default Values</p>
  CONSTANTS:
    gc_default_email_subject TYPE string VALUE 'ONGC CST Purchase Data - Fortnightly Report',
    gc_default_file_prefix   TYPE string VALUE 'ONGC_CST_PUR_',
    gc_gail_id_prefix        TYPE string VALUE 'GAIL',
    gc_max_records           TYPE i VALUE 10000.

  "! <p class="shorttext synchronized" lang="en">Conversion Constants</p>
  CONSTANTS:
    gc_mmbtu_to_scm_factor TYPE decfloat16 VALUE '26.853'.

ENDINTERFACE.
