CLASS lhc_zi_booking_aeo_m DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES: tt_entities TYPE TABLE FOR CREATE zi_booking_aeo_m\_BookSupp,
           tt_mapped   TYPE TABLE FOR MAPPED EARLY zi_booksupp_aeo_m.

    METHODS earlynumbering_cba_booksupp FOR NUMBERING
      IMPORTING entities FOR CREATE ZI_Booking_AEO_M\_Booksupp.

    METHODS get_latest_id
      IMPORTING iv_travel_id     TYPE /dmo/travel_id
                iv_booking_id    TYPE /dmo/booking_id
                it_entities      TYPE tt_entities
      RETURNING VALUE(rv_result) TYPE /dmo/booking_supplement_id.

    METHODS map_new_booking_supplements
      IMPORTING iv_start_id      TYPE /dmo/booking_supplement_id
                is_parent        TYPE LINE OF tt_entities
      RETURNING VALUE(rt_mapped) TYPE tt_mapped.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR ZI_Booking_AEO_M RESULT result.

    METHODS validatecurrencycode FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_booking_aeo_m~validatecurrencycode.

    METHODS validatecustomer FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_booking_aeo_m~validatecustomer.

    METHODS validateflightprice FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_booking_aeo_m~validateflightprice.

    METHODS validateconnection FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_booking_aeo_m~validateconnection.

    METHODS validatestatus FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_booking_aeo_m~validatestatus.
ENDCLASS.

CLASS lhc_zi_booking_aeo_m IMPLEMENTATION.
  METHOD earlynumbering_cba_booksupp.
    mapped-zi_booksupp_aeo_m = VALUE #( BASE mapped-zi_booksupp_aeo_m
      FOR GROUPS <group_key> OF <fs_entity> IN entities GROUP BY <fs_entity>-%tky
        LET
          lv_max_booking_supp_id = get_latest_id(
            iv_travel_id  = <group_key>-travelid
            iv_booking_id = <group_key>-bookingid
            it_entities   = entities )
        IN
          ( LINES OF map_new_booking_supplements(
              iv_start_id = lv_max_booking_supp_id
              is_parent   = VALUE #(
                entities[ KEY entity %tky = <group_key> ] OPTIONAL ) ) ) ).
  ENDMETHOD.

  METHOD get_latest_id.
    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY zi_booking_aeo_m BY \_BookSupp
        FROM CORRESPONDING #( it_entities )
        LINK DATA(lt_link_data).

    rv_result = REDUCE #(
      INIT lv_max_db = CONV /dmo/booking_supplement_id( '0' )
      FOR ls_link IN lt_link_data USING KEY entity WHERE ( source-travelid = iv_travel_id AND source-bookingid = iv_booking_id )
        NEXT lv_max_db = nmax( val1 = lv_max_db val2 = ls_link-target-bookingsupplementid ) ).

    rv_result = REDUCE #(
      INIT lv_max_buffer = rv_result
      FOR ls_entity IN it_entities USING KEY entity WHERE ( travelid = iv_travel_id AND bookingid = iv_booking_id )
        FOR ls_bookingsupp IN ls_entity-%target
          NEXT lv_max_buffer = nmax( val1 = lv_max_buffer val2 = ls_bookingsupp-BookingSupplementId ) ).
  ENDMETHOD.

  METHOD map_new_booking_supplements.
    rt_mapped = VALUE #(
      LET lv_running_id = iv_start_id IN
      FOR ls_booking_supp IN is_parent-%target INDEX INTO lv_idx
        LET
          lv_next_id = COND /dmo/booking_supplement_id(
            WHEN ls_booking_supp-bookingsupplementid IS INITIAL
            THEN lv_running_id + lv_idx
            ELSE ls_booking_supp-bookingsupplementid )
        IN
          ( %cid                = ls_booking_supp-%cid
            travelid            = is_parent-travelid
            bookingid           = is_parent-bookingid
            bookingsupplementid = lv_next_id               ) ).
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_travel_aeo_m IN LOCAL MODE
      ENTITY travel BY \_Booking
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
ENDCLASS.
