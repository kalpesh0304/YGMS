CLASS ygms_cx_cst_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_message.

    "! General error exception
    CONSTANTS:
      BEGIN OF general_error,
        msgid TYPE symsgid VALUE 'YGMS_MSG',
        msgno TYPE symsgno VALUE '011',
        attr1 TYPE scx_attrname VALUE 'MV_PARAM1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF general_error.

    "! File error exception
    CONSTANTS:
      BEGIN OF file_error,
        msgid TYPE symsgid VALUE 'YGMS_MSG',
        msgno TYPE symsgno VALUE '003',
        attr1 TYPE scx_attrname VALUE 'MV_PARAM1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF file_error.

    "! Authorization error
    CONSTANTS:
      BEGIN OF auth_error,
        msgid TYPE symsgid VALUE 'YGMS_MSG',
        msgno TYPE symsgno VALUE '007',
        attr1 TYPE scx_attrname VALUE 'MV_PARAM1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF auth_error.

    "! Location not found error
    CONSTANTS:
      BEGIN OF location_not_found,
        msgid TYPE symsgid VALUE 'YGMS_MSG',
        msgno TYPE symsgno VALUE '005',
        attr1 TYPE scx_attrname VALUE 'MV_PARAM1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF location_not_found.

    "! Material not found error
    CONSTANTS:
      BEGIN OF material_not_found,
        msgid TYPE symsgid VALUE 'YGMS_MSG',
        msgno TYPE symsgno VALUE '006',
        attr1 TYPE scx_attrname VALUE 'MV_PARAM1',
        attr2 TYPE scx_attrname VALUE 'MV_PARAM2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF material_not_found.

    "! File not found error
    CONSTANTS:
      BEGIN OF file_not_found,
        msgid TYPE symsgid VALUE 'YGMS_MSG',
        msgno TYPE symsgno VALUE '020',
        attr1 TYPE scx_attrname VALUE 'MV_PARAM1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF file_not_found.

    "! Upload failed error
    CONSTANTS:
      BEGIN OF upload_failed,
        msgid TYPE symsgid VALUE 'YGMS_MSG',
        msgno TYPE symsgno VALUE '021',
        attr1 TYPE scx_attrname VALUE 'MV_PARAM1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF upload_failed.

    "! Download failed error
    CONSTANTS:
      BEGIN OF download_failed,
        msgid TYPE symsgid VALUE 'YGMS_MSG',
        msgno TYPE symsgno VALUE '022',
        attr1 TYPE scx_attrname VALUE 'MV_PARAM1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF download_failed.

    "! ALV display error
    CONSTANTS:
      BEGIN OF alv_error,
        msgid TYPE symsgid VALUE 'YGMS_MSG',
        msgno TYPE symsgno VALUE '023',
        attr1 TYPE scx_attrname VALUE 'MV_PARAM1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF alv_error.

    "! No data error
    CONSTANTS:
      BEGIN OF no_data,
        msgid TYPE symsgid VALUE 'YGMS_MSG',
        msgno TYPE symsgno VALUE '024',
        attr1 TYPE scx_attrname VALUE 'MV_PARAM1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_data.

    "! Message parameters
    DATA: mv_param1 TYPE string,
          mv_param2 TYPE string.

    "! <p class="shorttext synchronized" lang="en">Constructor</p>
    "! @parameter textid | Text ID for message
    "! @parameter previous | Previous exception
    "! @parameter mv_param1 | First message parameter
    "! @parameter mv_param2 | Second message parameter
    METHODS constructor
      IMPORTING
        textid    LIKE if_t100_message=>t100key OPTIONAL
        previous  LIKE previous OPTIONAL
        mv_param1 TYPE string OPTIONAL
        mv_param2 TYPE string OPTIONAL.

ENDCLASS.


CLASS ygms_cx_cst_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).

    me->mv_param1 = mv_param1.
    me->mv_param2 = mv_param2.

    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = general_error.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
