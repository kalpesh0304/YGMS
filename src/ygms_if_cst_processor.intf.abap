INTERFACE ygms_if_cst_processor
  PUBLIC.

  "! <p class="shorttext synchronized" lang="en">Initialize the processor</p>
  "! @parameter iv_location_id | Location ID
  "! @parameter iv_date_from | Start date
  "! @parameter iv_date_to | End date
  METHODS initialize
    IMPORTING
      iv_location_id TYPE ygms_de_loc_id
      iv_date_from   TYPE datum
      iv_date_to     TYPE datum.

  "! <p class="shorttext synchronized" lang="en">Process data</p>
  "! @parameter rt_result | Processing result
  METHODS process
    RETURNING
      VALUE(rt_result) TYPE ygms_tt_purchase.

  "! <p class="shorttext synchronized" lang="en">Validate data</p>
  "! @parameter it_data | Data to validate
  "! @parameter rv_valid | Validation result
  METHODS validate
    IMPORTING
      it_data        TYPE ygms_tt_purchase
    RETURNING
      VALUE(rv_valid) TYPE abap_bool.

  "! <p class="shorttext synchronized" lang="en">Get messages</p>
  "! @parameter rt_messages | Messages table
  METHODS get_messages
    RETURNING
      VALUE(rt_messages) TYPE bapiret2_t.

ENDINTERFACE.
