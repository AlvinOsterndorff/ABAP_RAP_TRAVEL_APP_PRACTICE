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
      IMPORTING iv_start_id TYPE /dmo/booking_supplement_id
                is_parent   TYPE LINE OF tt_entities
      CHANGING  ct_mapped   TYPE tt_mapped.
ENDCLASS.

CLASS lhc_zi_booking_aeo_m IMPLEMENTATION.
  METHOD earlynumbering_cba_booksupp.
    DATA: lv_max_booking_supp_id TYPE /dmo/booking_supplement_id.

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<fs_entity>) GROUP BY <fs_entity>-%tky.
      lv_max_booking_supp_id = get_latest_id(
        iv_travel_id  = <fs_entity>-travelid
        iv_booking_id = <fs_entity>-bookingid
        it_entities   = entities ).

      map_new_booking_supplements(
        EXPORTING
          iv_start_id = lv_max_booking_supp_id
          is_parent   = <fs_entity>
        CHANGING
          ct_mapped   = mapped-zi_booksupp_aeo_m ).
    ENDLOOP.
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
    DATA(lv_running_id) = iv_start_id.

    LOOP AT is_parent-%target ASSIGNING FIELD-SYMBOL(<ls_new_booking_supp>).
      IF <ls_new_booking_supp>-bookingsupplementid IS INITIAL.
        lv_running_id += 1.
        <ls_new_booking_supp>-bookingsupplementid = lv_running_id.
      ENDIF.

      APPEND CORRESPONDING #( <ls_new_booking_supp> ) TO ct_mapped.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
