CLASS lhc_Travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
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

    METHODS rejectTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~rejectTravel RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Travel RESULT result.

    METHODS validatecustomer FOR VALIDATE ON SAVE
      IMPORTING keys FOR travel~validatecustomer.

    METHODS validatebookingfee FOR VALIDATE ON SAVE
      IMPORTING keys FOR travel~validatebookingfee.

    METHODS validatecurrencycode FOR VALIDATE ON SAVE
      IMPORTING keys FOR travel~validatecurrencycode.

    METHODS validatedates FOR VALIDATE ON SAVE
      IMPORTING keys FOR travel~validatedates.

    METHODS validatestatus FOR VALIDATE ON SAVE
      IMPORTING keys FOR travel~validatestatus.

    METHODS earlynumbering_cba_Booking FOR NUMBERING
      IMPORTING entities FOR CREATE Travel\_Booking.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Travel.
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
        FOR ls_entity IN lt_entities
          ( %cid = ls_entity-%cid
            %key = ls_entity-%key ) ).
      reported-travel = VALUE #(
        FOR ls_entity IN lt_entities
          ( %key = ls_entity-%key
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
    DATA(lo_travel_helper) = NEW zcl_travel_helper_aeo( ).

    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY travel BY \_booking
        FROM CORRESPONDING #( entities )
        LINK DATA(lt_link_data).

    mapped-zi_booking_aeo_m = VALUE #( BASE mapped-zi_booking_aeo_m
      FOR GROUPS <group_key> OF <fs_entity> IN entities GROUP BY <fs_entity>-travelid
        LET
          lv_max_booking_id = lo_travel_helper->get_latest_booking_id(
            iv_travel_id = <group_key>
            it_link_data = lt_link_data
            it_entities  = entities )
        IN
          ( LINES OF lo_travel_helper->map_new_bookings(
              iv_start_id = lv_max_booking_id
              is_entity   = VALUE #( entities[ KEY entity travelid = <group_key> ] OPTIONAL ) ) ) ).
  ENDMETHOD.

  METHOD acceptTravel.
    MODIFY ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY travel
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #(
          FOR key IN keys
            ( %tky          = key-%tky
              OverallStatus = 'A'      ) ).

    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY travel
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_result).

    result = VALUE #(
      FOR ls_result IN lt_result
        ( %tky   = ls_result-%tky
          %param = ls_result      ) ).
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

  METHOD rejectTravel.
    MODIFY ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY travel
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #(
          FOR key IN keys
            ( %tky          = key-%tky
              OverallStatus = 'X'      ) ).

    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY travel
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_result).

    result = VALUE #(
      FOR ls_result IN lt_result
        ( %tky   = ls_result-%tky
          %param = ls_result      ) ).
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY travel
        FIELDS ( travelid overallstatus )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_travel_result).

    result = VALUE #(
      FOR ls_travel_result IN lt_travel_result
        ( %tky = ls_travel_result-%tky
          %features-%action-acceptTravel = COND #(
            WHEN ls_travel_result-OverallStatus = 'A'
            THEN if_abap_behv=>fc-o-disabled
            ELSE if_abap_behv=>fc-o-enabled )
          %features-%action-rejectTravel = COND #(
            WHEN ls_travel_result-OverallStatus = 'X'
            THEN if_abap_behv=>fc-o-disabled
            ELSE if_abap_behv=>fc-o-enabled )
          %features-%assoc-_Booking = COND #(
            WHEN ls_travel_result-OverallStatus = 'X'
            THEN if_abap_behv=>fc-o-disabled
            ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.

  METHOD validateCustomer.
    DATA: lt_customer TYPE SORTED TABLE OF /dmo/customer WITH UNIQUE KEY customer_id.

    READ ENTITY IN LOCAL MODE zi_travel_aeo_m
      FIELDS ( customerid )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_customer_result).

    lt_customer = CORRESPONDING #( lt_customer_result DISCARDING DUPLICATES MAPPING customer_id = CustomerId ).

    DELETE lt_customer WHERE customer_id IS INITIAL.

    SELECT
      FROM /dmo/customer
      FIELDS customer_id
      FOR ALL ENTRIES IN @lt_customer_result
      WHERE customer_id = @lt_customer_result-customerid
      INTO TABLE @DATA(lt_customer_db).
    IF sy-subrc IS INITIAL.

    ENDIF.

    LOOP AT lt_customer_result ASSIGNING FIELD-SYMBOL(<fs_customer_result>).
      IF <fs_customer_result>-customerid IS INITIAL
      OR NOT line_exists( lt_customer_db[ customer_id = <fs_customer_result>-customerid ] ).
        APPEND VALUE #( %tky = <fs_customer_result>-%tky ) TO failed-travel.
        APPEND VALUE #(
          %element-customerid = if_abap_behv=>mk-on
          %msg = new /dmo/cm_flight_messages(
            textid      = /dmo/cm_flight_messages=>customer_unkown
            customer_id = <fs_customer_result>-customerid
            severity    = if_abap_behv_message=>severity-error )
        ) TO reported-travel.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateBookingFee.
  ENDMETHOD.

  METHOD validateCurrencyCode.
  ENDMETHOD.

  METHOD validateDates.
    DATA(lo_travel_helper) = NEW zcl_travel_helper_aeo( ).
    DATA(lv_system_Date) = cl_abap_context_info=>get_system_date( ).

    READ ENTITY IN LOCAL MODE zi_travel_aeo_m
      FIELDS ( begindate enddate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_travels).

    LOOP AT lt_travels ASSIGNING FIELD-SYMBOL(<fs_travel>).
      DATA(ls_result) = lo_travel_helper->validate_dates(
        iv_begin_date  = <fs_travel>-begindate
        iv_end_date    = <fs_travel>-enddate
        iv_system_date = lv_system_Date ).

      IF ls_result-are_valid_dates = abap_false.
        APPEND VALUE #( %tky = <fs_travel>-%tky ) TO failed-travel.
        APPEND VALUE #(
          %tky = <fs_travel>-%tky
          %msg = new /dmo/cm_flight_messages(
            textid      = ls_result-error_textid
            severity    = if_abap_behv_message=>severity-error
            begin_date  = <fs_travel>-begindate
            end_date    = <fs_travel>-enddate
            travel_id   = <fs_travel>-travelid )
          %element-begindate = if_abap_behv=>mk-on
          %element-enddate   = if_abap_behv=>mk-on
        ) TO reported-travel.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateStatus.
    READ ENTITY IN LOCAL MODE zi_travel_aeo_m
      FIELDS ( overallstatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_travels).

    failed-travel = VALUE #( BASE failed-travel
      FOR <fs_travel> IN lt_travels WHERE ( overallstatus NA 'OXA' )
        ( %tky = <fs_travel>-%tky ) ).

    reported-travel = VALUE #( BASE reported-travel
      FOR <fs_travel> IN lt_travels WHERE ( overallstatus NA 'OXA' )
        ( %tky = <fs_travel>-%tky
          %msg = new /dmo/cm_flight_messages(
            textid   = /dmo/cm_flight_messages=>status_invalid
            severity = if_abap_behv_message=>severity-error
            status   = <fs_travel>-overallstatus )
          %element-overallstatus = if_abap_behv=>mk-on ) ).
  ENDMETHOD.
ENDCLASS.
