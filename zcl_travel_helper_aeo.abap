CLASS zcl_travel_helper_aeo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: tt_entities_booking TYPE TABLE FOR CREATE zi_travel_aeo_m\_Booking,
           tt_mapped_booking   TYPE TABLE FOR MAPPED EARLY zi_booking_aeo_m,
           tt_link_data        TYPE TABLE FOR READ LINK zi_travel_aeo_m\\travel\_booking.

    METHODS get_latest_booking_id
      IMPORTING iv_travel_id     TYPE /dmo/travel_id
                it_link_data     TYPE tt_link_data
                it_entities      TYPE tt_entities_booking
      RETURNING VALUE(rv_result) TYPE /dmo/booking_id.

    METHODS map_new_bookings
      IMPORTING iv_start_id      TYPE /dmo/booking_id
                is_entity        TYPE LINE OF tt_entities_booking
      RETURNING VALUE(rt_mapped) TYPE tt_mapped_booking.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_travel_helper_aeo IMPLEMENTATION.
  METHOD get_latest_booking_id.
    rv_result = REDUCE #(
      INIT lv_max_db = CONV /dmo/booking_id( '0' )
      FOR ls_link IN it_link_data USING KEY entity WHERE ( source-travelid = iv_travel_id )
        NEXT lv_max_db = nmax( val1 = lv_max_db val2 = ls_link-target-BookingId ) ).

    rv_result = REDUCE #(
      INIT lv_max_buffer = rv_result
      FOR ls_entity IN it_entities USING KEY entity WHERE ( travelid = iv_travel_id )
        FOR ls_booking IN ls_entity-%target
          NEXT lv_max_buffer = nmax( val1 = lv_max_buffer val2 = ls_booking-BookingId ) ).
  ENDMETHOD.

  METHOD map_new_bookings.
    rt_mapped = VALUE #(
      LET lv_running_id = iv_start_id IN
      FOR ls_booking IN is_entity-%target INDEX INTO lv_idx
        LET
          lv_next_id = COND /dmo/booking_id(
            WHEN ls_booking-bookingid IS INITIAL
            THEN lv_running_id + lv_idx
            ELSE ls_booking-bookingid )
        IN
          ( %cid      = ls_booking-%cid
            travelid  = ls_booking-travelid
            bookingid = lv_next_id          ) ).
  ENDMETHOD.
ENDCLASS.
