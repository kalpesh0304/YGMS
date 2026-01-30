CLASS ygms_cl_cst_pdf_generator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor.

    METHODS generate_report
      IMPORTING
        it_data        TYPE ygms_tt_allocation
        iv_gail_id     TYPE ygms_de_gail_id
        iv_location_id TYPE ygms_de_loc_id
        iv_date_from   TYPE datum
        iv_date_to     TYPE datum
      EXPORTING
        ev_pdf_xstring TYPE xstring
        et_messages    TYPE bapiret2_t
      RAISING
        ygms_cx_cst_error.

    METHODS download_pdf
      IMPORTING
        iv_pdf_xstring TYPE xstring
        iv_file_path   TYPE string
      EXPORTING
        et_messages    TYPE bapiret2_t
      RAISING
        ygms_cx_cst_error.

    METHODS send_pdf_email
      IMPORTING
        iv_pdf_xstring   TYPE xstring
        iv_email_address TYPE ad_smtpadr
        iv_subject       TYPE string
        iv_body          TYPE string
      EXPORTING
        et_messages      TYPE bapiret2_t
      RAISING
        ygms_cx_cst_error.

    METHODS set_company_info
      IMPORTING
        iv_company_name TYPE string
        iv_company_addr TYPE string.

  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA: mv_company_name TYPE string,
          mv_company_addr TYPE string.

    METHODS build_html_report
      IMPORTING
        it_data        TYPE ygms_tt_allocation
        iv_gail_id     TYPE ygms_de_gail_id
        iv_location_id TYPE ygms_de_loc_id
        iv_date_from   TYPE datum
        iv_date_to     TYPE datum
      RETURNING
        VALUE(rv_html) TYPE string.

    METHODS convert_html_to_pdf
      IMPORTING
        iv_html            TYPE string
      RETURNING
        VALUE(rv_xstring)  TYPE xstring
      RAISING
        ygms_cx_cst_error.

    METHODS format_date
      IMPORTING
        iv_date        TYPE datum
      RETURNING
        VALUE(rv_date) TYPE string.

    METHODS format_number
      IMPORTING
        iv_number        TYPE any
      RETURNING
        VALUE(rv_number) TYPE string.

    METHODS add_message
      IMPORTING
        iv_type    TYPE symsgty
        iv_id      TYPE symsgid
        iv_number  TYPE symsgno
        iv_message TYPE string
      CHANGING
        ct_messages TYPE bapiret2_t.

ENDCLASS.

CLASS ygms_cl_cst_pdf_generator IMPLEMENTATION.

  METHOD constructor.
    mv_company_name = 'GAIL (India) Limited'.
    mv_company_addr = '16, Bhikaiji Cama Place, New Delhi - 110066'.
  ENDMETHOD.

  METHOD generate_report.
    DATA: lv_html TYPE string.

    CLEAR: ev_pdf_xstring, et_messages.

    IF it_data IS INITIAL.
      add_message(
        EXPORTING
          iv_type    = 'E'
          iv_id      = 'YGMS_CST'
          iv_number  = '010'
          iv_message = 'No data to generate report'
        CHANGING
          ct_messages = et_messages
      ).
      RETURN.
    ENDIF.

    " Build HTML report
    lv_html = build_html_report(
      it_data        = it_data
      iv_gail_id     = iv_gail_id
      iv_location_id = iv_location_id
      iv_date_from   = iv_date_from
      iv_date_to     = iv_date_to
    ).

    " Convert to PDF
    ev_pdf_xstring = convert_html_to_pdf( lv_html ).

    add_message(
      EXPORTING
        iv_type    = 'S'
        iv_id      = 'YGMS_CST'
        iv_number  = '011'
        iv_message = 'PDF report generated successfully'
      CHANGING
        ct_messages = et_messages
    ).
  ENDMETHOD.

  METHOD download_pdf.
    DATA: lt_binary TYPE STANDARD TABLE OF raw255,
          lv_length TYPE i.

    CLEAR et_messages.

    IF iv_pdf_xstring IS INITIAL.
      RAISE EXCEPTION TYPE ygms_cx_cst_error
        EXPORTING
          textid = ygms_cx_cst_error=>no_data.
    ENDIF.

    " Convert xstring to binary table
    CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
      EXPORTING
        buffer        = iv_pdf_xstring
      IMPORTING
        output_length = lv_length
      TABLES
        binary_tab    = lt_binary.

    " Download file
    CALL FUNCTION 'GUI_DOWNLOAD'
      EXPORTING
        filename                = iv_file_path
        filetype                = 'BIN'
        bin_filesize            = lv_length
      TABLES
        data_tab                = lt_binary
      EXCEPTIONS
        OTHERS                  = 1.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE ygms_cx_cst_error
        EXPORTING
          textid = ygms_cx_cst_error=>download_failed.
    ENDIF.

    add_message(
      EXPORTING
        iv_type    = 'S'
        iv_id      = 'YGMS_CST'
        iv_number  = '012'
        iv_message = |PDF downloaded to { iv_file_path }|
      CHANGING
        ct_messages = et_messages
    ).
  ENDMETHOD.

  METHOD send_pdf_email.
    DATA: lo_send_request  TYPE REF TO cl_bcs,
          lo_document      TYPE REF TO cl_document_bcs,
          lo_recipient     TYPE REF TO if_recipient_bcs,
          lo_sender        TYPE REF TO cl_sapuser_bcs,
          lt_body          TYPE soli_tab,
          lt_attachment    TYPE solix_tab,
          lv_sent          TYPE os_boolean.

    CLEAR et_messages.

    TRY.
        " Create send request
        lo_send_request = cl_bcs=>create_persistent( ).

        " Create document
        APPEND INITIAL LINE TO lt_body ASSIGNING FIELD-SYMBOL(<ls_body>).
        <ls_body>-line = iv_body.

        lo_document = cl_document_bcs=>create_document(
          i_type    = 'RAW'
          i_text    = lt_body
          i_subject = CONV #( iv_subject )
        ).

        " Add PDF attachment
        lt_attachment = cl_bcs_convert=>xstring_to_solix( iv_pdf_xstring ).

        lo_document->add_attachment(
          i_attachment_type    = 'PDF'
          i_attachment_subject = |CST_Report_{ sy-datum }.pdf|
          i_att_content_hex    = lt_attachment
        ).

        lo_send_request->set_document( lo_document ).

        " Add recipient
        lo_recipient = cl_cam_address_bcs=>create_internet_address( iv_email_address ).
        lo_send_request->add_recipient( lo_recipient ).

        " Set sender
        lo_sender = cl_sapuser_bcs=>create( sy-uname ).
        lo_send_request->set_sender( lo_sender ).

        " Send immediately
        lo_send_request->set_send_immediately( abap_true ).

        " Send
        lv_sent = lo_send_request->send( ).

        IF lv_sent = abap_true.
          COMMIT WORK.
          add_message(
            EXPORTING
              iv_type    = 'S'
              iv_id      = 'YGMS_CST'
              iv_number  = '013'
              iv_message = |Email sent to { iv_email_address }|
            CHANGING
              ct_messages = et_messages
          ).
        ELSE.
          add_message(
            EXPORTING
              iv_type    = 'E'
              iv_id      = 'YGMS_CST'
              iv_number  = '014'
              iv_message = 'Email could not be sent'
            CHANGING
              ct_messages = et_messages
          ).
        ENDIF.

      CATCH cx_bcs INTO DATA(lx_bcs).
        add_message(
          EXPORTING
            iv_type    = 'E'
            iv_id      = 'YGMS_CST'
            iv_number  = '015'
            iv_message = |Email error: { lx_bcs->get_text( ) }|
          CHANGING
            ct_messages = et_messages
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD set_company_info.
    mv_company_name = iv_company_name.
    mv_company_addr = iv_company_addr.
  ENDMETHOD.

  METHOD build_html_report.
    DATA: lv_total_mbg TYPE ygms_de_qty_mbg,
          lv_total_scm TYPE ygms_de_qty_scm.

    " Calculate totals
    LOOP AT it_data INTO DATA(ls_data).
      lv_total_mbg = lv_total_mbg + ls_data-alloc_qty_mbg.
      lv_total_scm = lv_total_scm + ls_data-alloc_qty_scm.
    ENDLOOP.

    " Build HTML
    rv_html = |<!DOCTYPE html>| &&
              |<html><head>| &&
              |<meta charset="UTF-8">| &&
              |<title>CST Purchase Report</title>| &&
              |<style>| &&
              |body \{ font-family: Arial, sans-serif; margin: 20px; \}| &&
              |.header \{ text-align: center; margin-bottom: 30px; \}| &&
              |.company \{ font-size: 18pt; font-weight: bold; \}| &&
              |.title \{ font-size: 14pt; margin-top: 10px; \}| &&
              |.info \{ margin: 20px 0; \}| &&
              |.info-row \{ margin: 5px 0; \}| &&
              |table \{ width: 100%; border-collapse: collapse; margin-top: 20px; \}| &&
              |th, td \{ border: 1px solid #333; padding: 8px; text-align: left; \}| &&
              |th \{ background-color: #f0f0f0; \}| &&
              |.number \{ text-align: right; \}| &&
              |.footer \{ margin-top: 30px; text-align: center; font-size: 10pt; \}| &&
              |</style></head><body>| &&
              |<div class="header">| &&
              |<div class="company">{ mv_company_name }</div>| &&
              |<div class="title">CST Purchase Data Report</div>| &&
              |</div>| &&
              |<div class="info">| &&
              |<div class="info-row"><strong>GAIL ID:</strong> { iv_gail_id }</div>| &&
              |<div class="info-row"><strong>Location:</strong> { iv_location_id }</div>| &&
              |<div class="info-row"><strong>Period:</strong> { format_date( iv_date_from ) } to { format_date( iv_date_to ) }</div>| &&
              |<div class="info-row"><strong>Generated:</strong> { format_date( sy-datum ) }</div>| &&
              |</div>| &&
              |<table>| &&
              |<tr>| &&
              |<th>Gas Day</th>| &&
              |<th>Location</th>| &&
              |<th>Material</th>| &&
              |<th>State</th>| &&
              |<th>Code</th>| &&
              |<th>Qty MMBTU</th>| &&
              |<th>Qty SCM</th>| &&
              |<th>GCV</th>| &&
              |<th>NCV</th>| &&
              |<th>Tax</th>| &&
              |</tr>|.

    LOOP AT it_data INTO ls_data.
      rv_html = rv_html &&
                |<tr>| &&
                |<td>{ format_date( ls_data-gas_day ) }</td>| &&
                |<td>{ ls_data-location_id }</td>| &&
                |<td>{ ls_data-material }</td>| &&
                |<td>{ ls_data-state }</td>| &&
                |<td>{ ls_data-state_code }</td>| &&
                |<td class="number">{ format_number( ls_data-alloc_qty_mbg ) }</td>| &&
                |<td class="number">{ format_number( ls_data-alloc_qty_scm ) }</td>| &&
                |<td class="number">{ format_number( ls_data-gcv ) }</td>| &&
                |<td class="number">{ format_number( ls_data-ncv ) }</td>| &&
                |<td>{ ls_data-tax_type }</td>| &&
                |</tr>|.
    ENDLOOP.

    rv_html = rv_html &&
              |<tr style="font-weight: bold;">| &&
              |<td colspan="5">Total</td>| &&
              |<td class="number">{ format_number( lv_total_mbg ) }</td>| &&
              |<td class="number">{ format_number( lv_total_scm ) }</td>| &&
              |<td colspan="3"></td>| &&
              |</tr>| &&
              |</table>| &&
              |<div class="footer">| &&
              |<p>{ mv_company_addr }</p>| &&
              |<p>Report generated on { format_date( sy-datum ) } at { sy-uzeit+0(2) }:{ sy-uzeit+2(2) }:{ sy-uzeit+4(2) }</p>| &&
              |</div>| &&
              |</body></html>|.
  ENDMETHOD.

  METHOD convert_html_to_pdf.
    DATA: lo_converter TYPE REF TO cl_abap_conv_out_ce,
          lv_xstring   TYPE xstring.

    " Convert HTML string to xstring
    lo_converter = cl_abap_conv_out_ce=>create( encoding = 'UTF-8' ).
    lo_converter->convert(
      EXPORTING
        data   = iv_html
      IMPORTING
        buffer = lv_xstring
    ).

    " Note: In a real SAP system, you would use proper PDF conversion
    " such as ADS (Adobe Document Services) or CONVERT_OTF_2_PDF
    " For this implementation, we return the HTML as xstring
    " which can be processed by external PDF generators
    rv_xstring = lv_xstring.
  ENDMETHOD.

  METHOD format_date.
    IF iv_date IS INITIAL.
      rv_date = ''.
    ELSE.
      rv_date = |{ iv_date+6(2) }.{ iv_date+4(2) }.{ iv_date+0(4) }|.
    ENDIF.
  ENDMETHOD.

  METHOD format_number.
    DATA: lv_string TYPE string.

    WRITE iv_number TO lv_string.
    rv_number = condense( lv_string ).
  ENDMETHOD.

  METHOD add_message.
    DATA: ls_message TYPE bapiret2.

    ls_message-type       = iv_type.
    ls_message-id         = iv_id.
    ls_message-number     = iv_number.
    ls_message-message    = iv_message.
    APPEND ls_message TO ct_messages.
  ENDMETHOD.

ENDCLASS.
