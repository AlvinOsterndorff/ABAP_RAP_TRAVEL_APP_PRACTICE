CLASS lcl_helper DEFINITION.
  PUBLIC SECTION.
    TYPES: tt_entities    TYPE TABLE FOR CREATE zi_booking_aeo_m\_BookSupp,
       tt_mapped      TYPE TABLE FOR MAPPED EARLY zi_booksupp_aeo_m,
       tt_link_data   TYPE TABLE FOR READ LINK zi_travel_aeo_m\\booking\_booksupp,
       tt_travel_keys TYPE TABLE FOR ACTION IMPORT zi_travel_aeo_m\\travel~recalctotalprice.

    CLASS-METHODS get_latest_id
      IMPORTING iv_travel_id     TYPE /dmo/travel_id
                iv_booking_id    TYPE /dmo/booking_id
                it_link_data     TYPE tt_link_data
                it_entities      TYPE tt_entities
      RETURNING VALUE(rv_result) TYPE /dmo/booking_supplement_id.

    CLASS-METHODS map_new_booking_supplements
      IMPORTING iv_start_id      TYPE /dmo/booking_supplement_id
                is_parent        TYPE LINE OF tt_entities
      RETURNING VALUE(rt_mapped) TYPE tt_mapped.
ENDCLASS.

CLASS lcl_helper IMPLEMENTATION.
  METHOD get_latest_id.
    rv_result = REDUCE #(
      INIT lv_max_db = CONV /dmo/booking_supplement_id( '0' )
      FOR <link> IN it_link_data USING KEY entity WHERE ( source-travelid = iv_travel_id AND source-bookingid = iv_booking_id )
        NEXT lv_max_db = nmax( val1 = lv_max_db val2 = <link>-target-bookingsupplementid ) ).

    rv_result = REDUCE #(
      INIT lv_max_buffer = rv_result
      FOR <entity> IN it_entities USING KEY entity WHERE ( travelid = iv_travel_id AND bookingid = iv_booking_id )
        FOR ls_bookingsupp IN <entity>-%target
          NEXT lv_max_buffer = nmax( val1 = lv_max_buffer val2 = ls_bookingsupp-BookingSupplementId ) ).
  ENDMETHOD.

  METHOD map_new_booking_supplements.
    rt_mapped = VALUE #(
      LET lv_running_id = iv_start_id IN
      FOR <booking_supp> IN is_parent-%target INDEX INTO lv_idx
        LET
          lv_next_id = COND /dmo/booking_supplement_id(
            WHEN <booking_supp>-bookingsupplementid IS INITIAL
            THEN lv_running_id + lv_idx
            ELSE <booking_supp>-bookingsupplementid )
        IN
          ( %cid                = <booking_supp>-%cid
            travelid            = is_parent-travelid
            bookingid           = is_parent-bookingid
            bookingsupplementid = lv_next_id               ) ).
  ENDMETHOD.
ENDCLASS.

CLASS lhc_zi_booking_aeo_m DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS earlynumbering_cba_booksupp FOR NUMBERING
      IMPORTING entities FOR CREATE Booking\_Booksupp.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Booking RESULT result.

    METHODS validatecurrencycode FOR VALIDATE ON SAVE
      IMPORTING keys FOR Booking~validatecurrencycode.

    METHODS validatecustomer FOR VALIDATE ON SAVE
      IMPORTING keys FOR Booking~validatecustomer.

    METHODS validateflightprice FOR VALIDATE ON SAVE
      IMPORTING keys FOR Booking~validateflightprice.

    METHODS validateconnection FOR VALIDATE ON SAVE
      IMPORTING keys FOR Booking~validateconnection.

    METHODS validatestatus FOR VALIDATE ON SAVE
      IMPORTING keys FOR Booking~validatestatus.

    METHODS calculatetotalprice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Booking~calculatetotalprice.
ENDCLASS.

CLASS lhc_zi_booking_aeo_m IMPLEMENTATION.
  METHOD earlynumbering_cba_booksupp.
    DATA: max_booksupp_id TYPE /dmo/booking_supplement_id.

    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY Booking BY \_BookSupp
        FROM CORRESPONDING #( entities )
        LINK DATA(lt_link_data).

     mapped-bookingsupplement = VALUE #( BASE mapped-bookingsupplement
      FOR GROUPS <group_key> OF <fs_entity> IN entities GROUP BY <fs_entity>-%tky
        LET
          lv_max_booking_supp_id = lcl_helper=>get_latest_id(
            iv_travel_id  = <group_key>-travelid
            iv_booking_id = <group_key>-bookingid
            it_link_data  = lt_link_data
            it_entities   = entities )
        IN
          ( LINES OF lcl_helper=>map_new_booking_supplements(
              iv_start_id = lv_max_booking_supp_id
              is_parent   = VALUE #( entities[ KEY entity %tky = <group_key> ] OPTIONAL ) ) ) ).
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY Booking
        FIELDS ( travelid bookingstatus )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_booking_result).

    result = VALUE #(
      FOR ls_booking_result IN lt_booking_result
        ( %tky = ls_booking_result-%tky
          %features-%assoc-_booksupp = COND #(
            WHEN ls_booking_result-bookingstatus = 'X'
            THEN if_abap_behv=>fc-o-disabled
            ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.

  METHOD validateCurrencyCode.
  ENDMETHOD.

  METHOD validateCustomer.
  ENDMETHOD.

  METHOD validateFlightPrice.
  ENDMETHOD.

  METHOD validateConnection.
  ENDMETHOD.

  METHOD validateStatus.
  ENDMETHOD.

  METHOD calculateTotalPrice.
    MODIFY ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY travel
      EXECUTE recalctotalprice
      FROM VALUE tt_travel_keys( FOR ls_key IN keys ( %tky = VALUE #( travelid = ls_key-travelid ) ) ).
  ENDMETHOD.
ENDCLASS.
