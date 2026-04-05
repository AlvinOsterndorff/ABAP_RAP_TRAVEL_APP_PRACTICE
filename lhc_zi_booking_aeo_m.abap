CLASS lhc_Travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES: tt_entities_booking TYPE TABLE FOR CREATE zi_travel_aeo_m\_Booking,
           tt_mapped_booking   TYPE TABLE FOR MAPPED EARLY zi_booking_aeo_m.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Travel RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Travel RESULT result.
    METHODS acceptTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~acceptTravel RESULT result.

    METHODS copyTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~copyTravel.

    METHODS recalcTotalPrice FOR MODIFY
      IMPORTING keys FOR ACTION Travel~recalcTotalPrice.

    METHODS rejectTavel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~rejectTavel RESULT result.

    METHODS earlynumbering_cba_Booking FOR NUMBERING
      IMPORTING entities FOR CREATE Travel\_Booking.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Travel.

    METHODS get_latest_booking_id
      IMPORTING iv_travel_id     TYPE /dmo/travel_id
                it_entities      TYPE tt_entities_booking
      RETURNING VALUE(rv_result) TYPE /dmo/booking_id.

    METHODS map_new_bookings
      IMPORTING iv_start_id      TYPE /dmo/booking_id
                is_entity        TYPE LINE OF tt_entities_booking
      RETURNING VALUE(rt_mapped) TYPE tt_mapped_booking.
ENDCLASS.

CLASS lhc_Travel IMPLEMENTATION.
  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD earlynumbering_create.
    DATA(lt_entities) = entities.
    DELETE lt_entities WHERE travelid IS NOT INITIAL.

    TRY.
      cl_numberrange_runtime=>number_get(
        EXPORTING
          nr_range_nr       = '01'
          object            = '/DMO/TRV_M'
          quantity          = CONV #( lines( lt_entities ) )
        IMPORTING
          number            = DATA(lv_latest_num)
          returncode        = DATA(lv_return_code)
          returned_quantity = DATA(lv_qty) ).
    CATCH cx_nr_object_not_found.
    CATCH cx_number_ranges INTO DATA(lo_error).
      failed-travel = VALUE #(
        FOR ls_entity IN lt_entities (
          %cid = ls_entity-%cid
          %key = ls_entity-%key ) ).
      reported-travel = VALUE #(
        FOR ls_entity IN lt_entities (
          %key = ls_entity-%key
          %msg = lo_error ) ).

      EXIT.
    ENDTRY.

    ASSERT lv_qty = lines( lt_entities ).

    mapped-travel = VALUE #(
      FOR ls_entity IN lt_entities INDEX INTO idx (
        %cid = ls_entity-%cid
        travelid = ( lv_latest_num - lv_qty ) + idx ) ).

  ENDMETHOD.

  METHOD earlynumbering_cba_Booking.
    mapped-zi_booking_aeo_m = VALUE #( BASE mapped-zi_booking_aeo_m
      FOR GROUPS <group_key> OF <fs_entity> IN entities GROUP BY <fs_entity>-travelid
        LET
          lv_max_booking_id = get_latest_booking_id(
            iv_travel_id = <group_key>
            it_entities  = entities )
        IN
          ( LINES OF map_new_bookings(
              iv_start_id = lv_max_booking_id
              is_entity = VALUE #( entities[ KEY entity travelid = <group_key> ] OPTIONAL ) ) ) ).
  ENDMETHOD.

  METHOD acceptTravel.
  ENDMETHOD.

  METHOD copyTravel.
    DATA: lt_travel       TYPE TABLE FOR CREATE zi_travel_aeo_m,
          lt_booking_cba  TYPE TABLE FOR CREATE zi_travel_aeo_m\_Booking,
          lt_booksupp_cba TYPE TABLE FOR CREATE zi_booking_aeo_m\_BookSupp.

    READ TABLE keys ASSIGNING FIELD-SYMBOL(<fs_key_without_cid>) WITH KEY %cid = ''.
    ASSERT <fs_key_without_cid> IS NOT ASSIGNED.

    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY Travel
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_travel_read)
         FAILED DATA(lt_failed).
    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY Travel BY \_Booking
        ALL FIELDS WITH CORRESPONDING #( lt_travel_read )
        RESULT DATA(lt_booking_read).
    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY ZI_Booking_AEO_M BY \_BookSupp
        ALL FIELDS WITH CORRESPONDING #( lt_booking_read )
        RESULT DATA(lt_bookingsupp_read).

    lt_travel = VALUE #(
      FOR ls_travel_read in lt_travel_read
        ( %cid = keys[ KEY entity travelid = ls_travel_read-TravelId ]-%cid
          %data = VALUE #(
            BASE CORRESPONDING #( ls_travel_read EXCEPT travelid )
            begindate = cl_abap_context_info=>get_system_date( )
            EndDate = cl_abap_context_info=>get_system_date( ) + 30
            OverallStatus = 'O' ) ) ).
    lt_booking_cba = VALUE #(
      FOR ls_travel_read IN lt_travel_read
        ( %cid_ref = keys[ KEY entity travelid = ls_travel_read-TravelId ]-%cid
          %target = VALUE #(
            FOR ls_booking_read in lt_booking_read USING KEY entity WHERE ( travelid = ls_travel_read-travelid )
              ( %cid = keys[ KEY entity travelid = ls_travel_read-travelid ]-%cid && ls_booking_read-bookingid
                %data = VALUE #(
                  BASE CORRESPONDING #( ls_booking_read EXCEPT travelid )
                  bookingstatus = 'N' ) ) ) ) ).
    lt_booksupp_cba = VALUE #(
      FOR ls_booking_read IN lt_booking_read
        ( %cid_ref = keys[ KEY entity travelid = ls_booking_read-TravelId ]-%cid && ls_booking_read-bookingid
          %target = VALUE #(
            FOR ls_bookingsupp_read IN lt_bookingsupp_read USING KEY entity
            WHERE ( travelid = ls_booking_read-travelid AND bookingid = ls_booking_read-bookingid )
              ( %cid = ls_booking_read-travelid && ls_booking_read-bookingid && ls_bookingsupp_read-bookingsupplementid
                %data = CORRESPONDING #( ls_bookingsupp_read EXCEPT travelid bookingid ) ) ) ) ).

    MODIFY ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY Travel
        CREATE FIELDS ( AgencyId CustomerId BeginDate EndDate BookingFee TotalPrice CurrencyCode OverallStatus Description )
        WITH lt_travel
      ENTITY Travel CREATE BY \_Booking
        FIELDS ( BookingId BookingDate CustomerId CarrierId ConnectionId FlightDate FlightPrice CurrencyCode BookingStatus )
        WITH lt_booking_cba
      ENTITY ZI_Booking_AEO_M CREATE BY \_BookSupp
        FIELDS ( BookingSupplementId SupplementId Price CurrencyCode )
        WITH lt_booksupp_cba
      MAPPED DATA(lt_mapped).

    mapped-travel = lt_mapped-travel.
    mapped-zi_booking_aeo_m = lt_mapped-zi_booking_aeo_m.
    mapped-zi_booksupp_aeo_m = lt_mapped-zi_booksupp_aeo_m.
  ENDMETHOD.

  METHOD recalcTotalPrice.
  ENDMETHOD.

  METHOD rejectTavel.
  ENDMETHOD.

  METHOD get_latest_booking_id.
    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY travel BY \_booking
        FROM CORRESPONDING #( it_entities )
        LINK DATA(lt_link_data).

    rv_result = REDUCE #(
      INIT lv_max_db = CONV /dmo/booking_id( '0' )
      FOR ls_link IN lt_link_data USING KEY entity WHERE ( source-travelid = iv_travel_id )
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
          ( %cid = ls_booking-%cid
            travelid = ls_booking-travelid
            bookingid = lv_next_id ) ).
  ENDMETHOD.
ENDCLASS.
