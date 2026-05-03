CLASS zcl_aux_travel_aeo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: tt_log TYPE STANDARD TABLE OF zlog_trvl_aeo_m.

    CLASS-METHODS:
      log_changes
        IMPORTING it_data      TYPE ANY TABLE
                  iv_operation TYPE string
        CHANGING  ct_log       TYPE tt_log,

      get_changed_fields
        IMPORTING is_row                   TYPE any
        RETURNING VALUE(rt_changed_fields) TYPE string_table,

      get_field_value
        IMPORTING is_row          TYPE any
                  iv_field_name   TYPE string
        RETURNING VALUE(rv_value) TYPE string.
  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES: BEGIN OF ts_structure_data,
             entity_name TYPE string,
             components  TYPE cl_abap_structdescr=>component_table,
           END OF ts_structure_data.

    CLASS-DATA: gt_component_cache TYPE HASHED TABLE OF ts_structure_data WITH UNIQUE KEY entity_name.
ENDCLASS.



CLASS zcl_aux_travel_aeo IMPLEMENTATION.
  METHOD log_changes.
    LOOP AT it_data ASSIGNING FIELD-SYMBOL(<travel>).
      DATA(travel_id) = zcl_aux_travel_aeo=>get_field_value(
        is_row        = <travel>
        iv_field_name = 'TRAVELID' ).
      DATA(changed_fields) = zcl_aux_travel_aeo=>get_changed_fields( <travel> ).

      LOOP AT changed_fields ASSIGNING FIELD-SYMBOL(<changed_field_name>).
        DATA(changed_field_value) = zcl_aux_travel_aeo=>get_field_value(
          is_row        = <travel>
          iv_field_name = <changed_field_name> ).

        TRY.
          APPEND VALUE #(
            travel_id          = travel_id
            change_id          = cl_system_uuid=>create_uuid_x16_static( )
            change_operation   = iv_operation
            changed_field_name = <changed_field_name>
            new_value          = changed_field_value
            created_at         = utclong_current( )
          ) TO ct_log.
        CATCH cx_uuid_error.
          "handle exception
        ENDTRY.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_changed_fields.
    ASSIGN COMPONENT '%CONTROL' OF STRUCTURE is_row TO FIELD-SYMBOL(<control>).
    IF sy-subrc = 0.
      DATA(lo_descriptor) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( <control> ) ).
      DATA(name) = lo_descriptor->get_relative_name( ).

      READ TABLE gt_component_cache WITH TABLE KEY entity_name = name ASSIGNING FIELD-SYMBOL(<cached_structure_data>).
      IF sy-subrc <> 0.
        INSERT VALUE #(
          entity_name = name
          components  = lo_descriptor->get_components( )
        ) INTO TABLE gt_component_cache ASSIGNING <cached_structure_data>.
      ENDIF.

      LOOP AT <cached_structure_data>-components ASSIGNING FIELD-SYMBOL(<component>).
        ASSIGN COMPONENT <component>-name OF STRUCTURE <control> TO FIELD-SYMBOL(<flag>).
        IF sy-subrc = 0 AND <flag> = if_abap_behv=>mk-on.
          APPEND <component>-name TO rt_changed_fields.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD get_field_value.
    ASSIGN COMPONENT iv_field_name OF STRUCTURE is_row TO FIELD-SYMBOL(<value>).
    IF sy-subrc = 0.
      rv_value = |{ <value> }|.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
