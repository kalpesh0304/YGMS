CLASS ygms_cl_cst_email_sender DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! <p class="shorttext synchronized" lang="en">Send email with data</p>
    METHODS send
      IMPORTING
        iv_email_address TYPE ad_smtpadr OPTIONAL
        iv_location_id   TYPE ygms_de_loc_id
        iv_date_from     TYPE datum
        iv_date_to       TYPE datum
      RAISING
        cx_send_req_bcs.

ENDCLASS.


CLASS ygms_cl_cst_email_sender IMPLEMENTATION.

  METHOD send.
    DATA: lo_send_request TYPE REF TO cl_bcs,
          lo_document     TYPE REF TO cl_document_bcs,
          lo_recipient    TYPE REF TO if_recipient_bcs,
          lo_sender       TYPE REF TO cl_sapuser_bcs,
          lt_text         TYPE bcsy_text,
          lv_subject      TYPE so_obj_des.

    " Build email subject
    lv_subject = |ONGC CST Purchase Data - { iv_location_id } - { iv_date_from DATE = USER } to { iv_date_to DATE = USER }|.

    " Build email body
    APPEND |Dear Team,| TO lt_text.
    APPEND || TO lt_text.
    APPEND |Please find attached the ONGC CST Purchase Data for:| TO lt_text.
    APPEND |  Location: { iv_location_id }| TO lt_text.
    APPEND |  Period: { iv_date_from DATE = USER } to { iv_date_to DATE = USER }| TO lt_text.
    APPEND || TO lt_text.
    APPEND |This is an auto-generated email from GAIL GMS System.| TO lt_text.
    APPEND || TO lt_text.
    APPEND |Regards,| TO lt_text.
    APPEND |GAIL GMS Team| TO lt_text.

    TRY.
        " Create send request
        lo_send_request = cl_bcs=>create_persistent( ).

        " Create document
        lo_document = cl_document_bcs=>create_document(
          i_type    = 'RAW'
          i_text    = lt_text
          i_subject = lv_subject
        ).

        " Add document to send request
        lo_send_request->set_document( lo_document ).

        " Set sender
        lo_sender = cl_sapuser_bcs=>create( sy-uname ).
        lo_send_request->set_sender( lo_sender ).

        " Add recipient
        IF iv_email_address IS NOT INITIAL.
          lo_recipient = cl_cam_address_bcs=>create_internet_address( iv_email_address ).
          lo_send_request->add_recipient( lo_recipient ).
        ENDIF.

        " Send
        lo_send_request->set_send_immediately( abap_true ).
        lo_send_request->send( ).

        COMMIT WORK.

      CATCH cx_bcs INTO DATA(lx_bcs).
        RAISE EXCEPTION TYPE cx_send_req_bcs
          EXPORTING
            previous = lx_bcs.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
