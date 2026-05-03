CLASS lcl_travel_helper DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS get_latest_booking_id
      IMPORTING iv_travel_id     TYPE /dmo/travel_id
                it_link_data     TYPE tt_link_data
                it_entities      TYPE tt_entities_booking
      RETURNING VALUE(rv_result) TYPE /dmo/booking_id.

    CLASS-METHODS map_new_bookings
      IMPORTING iv_start_id      TYPE /dmo/booking_id
                is_entity        TYPE LINE OF tt_entities_booking
      RETURNING VALUE(rt_mapped) TYPE tt_mapped_booking.

    CLASS-METHODS validate_dates
      IMPORTING iv_begin_date    TYPE /dmo/begin_date
                iv_end_date      TYPE /dmo/end_date
                iv_system_date   TYPE cl_abap_context_info=>ty_system_date
      RETURNING VALUE(rs_result) TYPE tt_date_check_result.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS lcl_travel_helper IMPLEMENTATION.
   METHOD get_latest_booking_id.
    rv_result = REDUCE #(
      INIT lv_max_db = CONV /dmo/booking_id( '0' )
      FOR <link> IN it_link_data USING KEY entity WHERE ( source-travelid = iv_travel_id )
        NEXT lv_max_db = nmax( val1 = lv_max_db val2 = <link>-target-BookingId ) ).

    rv_result = REDUCE #(
      INIT lv_max_buffer = rv_result
      FOR <entity> IN it_entities USING KEY entity WHERE ( travelid = iv_travel_id )
        FOR ls_booking IN <entity>-%target
          NEXT lv_max_buffer = nmax( val1 = lv_max_buffer val2 = ls_booking-BookingId ) ).
  ENDMETHOD.

  METHOD map_new_bookings.
    rt_mapped = VALUE #(
      LET lv_running_id = iv_start_id IN
      FOR <booking> IN is_entity-%target INDEX INTO lv_idx
        LET
          lv_next_id = COND /dmo/booking_id(
            WHEN <booking>-bookingid IS INITIAL
            THEN lv_running_id + lv_idx
            ELSE <booking>-bookingid )
        IN
          ( %cid      = <booking>-%cid
            travelid  = <booking>-travelid
            bookingid = lv_next_id         ) ).
  ENDMETHOD.

  METHOD validate_dates.
    DATA(lv_error_textid) = COND scx_t100key(
      WHEN iv_begin_date IS INITIAL
        THEN /dmo/cm_flight_messages=>enter_begin_date
      WHEN iv_end_date IS INITIAL
        THEN /dmo/cm_flight_messages=>enter_end_date
      WHEN iv_end_date < iv_begin_date
        THEN /dmo/cm_flight_messages=>begin_date_bef_end_date
      WHEN iv_begin_date < iv_system_date
        THEN /dmo/cm_flight_messages=>begin_date_on_or_bef_sysdate ).

    rs_result = VALUE #(
      are_valid_dates = COND #( WHEN lv_error_textid IS INITIAL THEN abap_true ELSE abap_false )
      error_textid = lv_error_textid ).
  ENDMETHOD.
ENDCLASS.

CLASS lsc_zi_travel_aeo_m DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.

CLASS lsc_zi_travel_aeo_m IMPLEMENTATION.
  METHOD save_modified.
    DATA: travel_log   TYPE STANDARD TABLE OF zlog_trvl_aeo_m,
          change_table TYPE TABLE FOR CHANGE zi_travel_aeo_m\\travel.

    IF create-travel IS NOT INITIAL.
      change_table = create-travel.

      zcl_aux_travel_aeo=>log_changes(
        EXPORTING
          it_data      = change_table
          iv_operation = 'CREATE'
        CHANGING
          ct_log       = travel_log ).
    ENDIF.

    IF update-travel IS NOT INITIAL.
      change_table = update-travel.

      zcl_aux_travel_aeo=>log_changes(
        EXPORTING
          it_data      = change_table
          iv_operation = 'UPDATE'
        CHANGING
          ct_log       = travel_log ).
    ENDIF.

    IF delete-travel IS NOT INITIAL.
      LOOP AT delete-travel ASSIGNING FIELD-SYMBOL(<delete>).
        TRY.
          APPEND VALUE #(
            travel_id        = <delete>-travelid
            change_id        = cl_system_uuid=>create_uuid_x16_static( )
            change_operation = 'DELETE'
            created_at       = utclong_current( )
          ) TO travel_log.
        CATCH cx_uuid_error.
          "handle exception
        ENDTRY.
      ENDLOOP.
    ENDIF.

    IF travel_log IS NOT INITIAL.
      INSERT zlog_trvl_aeo_m FROM TABLE @travel_log.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

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

    METHODS calculatetotalprice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR travel~calculatetotalprice.

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
    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY travel BY \_booking
        FROM CORRESPONDING #( entities )
        LINK DATA(lt_link_data).

    mapped-booking = VALUE #( BASE mapped-booking
      FOR GROUPS <group_key> OF <fs_entity> IN entities GROUP BY <fs_entity>-travelid
        LET
          lv_max_booking_id = lcl_travel_helper=>get_latest_booking_id(
            iv_travel_id = <group_key>
            it_link_data = lt_link_data
            it_entities  = entities )
        IN
          ( LINES OF lcl_travel_helper=>map_new_bookings(
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
      ENTITY booking BY \_BookSupp
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
      ENTITY booking CREATE BY \_BookSupp
        FIELDS ( BookingSupplementId SupplementId Price CurrencyCode )
        WITH lt_booksupp_cba
      MAPPED DATA(lt_mapped).

    mapped-travel = lt_mapped-travel.
    mapped-booking = lt_mapped-booking.
    mapped-bookingsupplement = lt_mapped-bookingsupplement.
  ENDMETHOD.

  METHOD recalcTotalPrice.
    TYPES: BEGIN OF ts_total,
             total_price   TYPE /dmo/total_price,
             currency_code TYPE /dmo/currency_code,
           END OF ts_total.
    DATA: lt_total           TYPE TABLE OF ts_total,
          lv_converted_price TYPE /dmo/total_price.

    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY travel
        FIELDS ( bookingfee currencycode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_travel).

    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY travel BY \_Booking
        FIELDS ( flightprice currencycode )
        WITH CORRESPONDING #( lt_travel )
        RESULT DATA(lt_booking).

    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY booking BY \_BookSupp
        FIELDS ( price currencycode )
        WITH CORRESPONDING #( lt_booking )
        RESULT DATA(lt_booksupp).

    LOOP AT lt_travel ASSIGNING FIELD-SYMBOL(<fs_travel>) WHERE currencycode IS NOT INITIAL.
      lt_total = VALUE #( ( total_price = <fs_travel>-bookingfee currency_code = <fs_travel>-currencycode ) ).

      LOOP AT lt_booking ASSIGNING FIELD-SYMBOL(<fs_booking>) USING KEY entity
      WHERE travelid = <fs_travel>-travelid AND currencycode IS NOT INITIAL.
        APPEND VALUE #( total_price = <fs_booking>-flightprice currency_code = <fs_booking>-currencycode ) TO lt_total.

        LOOP AT lt_booksupp ASSIGNING FIELD-SYMBOL(<fs_booksupp>) USING KEY entity
        WHERE travelid = <fs_booking>-travelid AND bookingid = <fs_booking>-bookingid AND currencycode IS NOT INITIAL.
          APPEND VALUE #( total_price = <fs_booksupp>-price currency_code = <fs_booksupp>-currencycode ) TO lt_total.
        ENDLOOP.
      ENDLOOP.

      LOOP AT lt_total ASSIGNING FIELD-SYMBOL(<fs_total>).
        IF <fs_total>-currency_code = <fs_travel>-currencycode.
          lv_converted_price = <fs_total>-total_price.
        ELSE.
          /dmo/cl_flight_amdp=>convert_currency(
            EXPORTING
              iv_amount               = <fs_total>-total_price
              iv_currency_code_source = <fs_total>-currency_code
              iv_currency_code_target = <fs_travel>-currencycode
              iv_exchange_rate_date   = cl_abap_context_info=>get_system_date( )
            IMPORTING
              ev_amount               = lv_converted_price ).
        ENDIF.

        <fs_travel>-totalprice += lv_converted_price.
      ENDLOOP.
    ENDLOOP.

    MODIFY ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY travel
        UPDATE FIELDS ( totalprice )
        WITH CORRESPONDING #( lt_travel ).
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
      FOR ALL ENTRIES IN @lt_customer
      WHERE customer_id = @lt_customer-customer_id
      INTO TABLE @DATA(lt_customer_db).

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
    DATA(lv_system_Date) = cl_abap_context_info=>get_system_date( ).

    READ ENTITY IN LOCAL MODE zi_travel_aeo_m
      FIELDS ( begindate enddate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_travels).

    LOOP AT lt_travels ASSIGNING FIELD-SYMBOL(<fs_travel>).
      DATA(ls_result) = lcl_travel_helper=>validate_dates(
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

  METHOD calculateTotalPrice.
    MODIFY ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY travel
        EXECUTE recalcTotalPrice
        FROM CORRESPONDING #( keys ).
  ENDMETHOD.
ENDCLASS.
