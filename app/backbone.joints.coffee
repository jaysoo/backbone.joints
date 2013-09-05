Joints = Backbone.Joints = {}


# Types of relations.
Joints.HasOne = 'HasOne'
Joints.HasMany = 'HasMany'

# Functions for creating relations.
Joints.hasOne = (modelClass) -> {
  type: Joints.HasOne
  relatedModel: modelClass
}

Joints.hasMany = (collectionClass) -> {
  type: Joints.HasMany
  collectionType: collectionClass
}


# Model cache for initialized instances.
#
# Key is based on the Model class and ID.
# Extended Backbone Model with special handlers.
class Joints.Model extends Backbone.Model
  # If cache is true, then enable instance store.
  # A model is cached using its `id`. Whenever a model
  # is newed with `id` matching an existing model, the
  # same instance is returned.
  cache: true

  # Constructor override that supports instance caching.
  #
  # **NOTE:** You *must* always override the `constructor` for any `Backbone.Joints.Model` subclass.
  #
  # e.g.
  #
  #     class Foo extends Backbone.Joints.Model
  #       constructor: -> return super
  #
  #
  # This override is super-duper important, otherwise the instance will not return properly!!!
  #
  #
  # Alternatively, you can also use the `Backbone.Joints.Model.extend` method.
  #
  # Foo = Backbone.Join.Model.extend(
  #   # ...
  # )
  constructor: (attrs = {}, options = {}) ->
    @constructor::_cache or=
      store: {}
      counts: {}

    # Build relations

    # If cache is enabled for this model
    # **and** it has been cached already.
    if @cache and (model = @capture(attrs))
        # Make sure we store the model's collection on itself
        # if it belongs to one.
        if options.collection and not model.collection
          model.collection = options.collection
        return model

    return super

  # Method to get key for instance cache.
  cacheKey: (attrs) -> @id or attrs?[@idAttribute]

  # Captures and returns an instance of the model.
  #
  # If no instances exist for the Model given the ID, then `null` is returned.
  capture: (attrs, options) ->
    key = @cacheKey attrs

    unless key?
      @cached = false
      return

    model = @_cache.store[key]

    if model is this
      return this

    if model
      @_cache.counts[key]++
      model.set attrs, options
      return model

    @_cache.store[key] = this
    @_cache.counts[key] = 1
    @cached = true

    # No instances yet
    return null

  # Releases this model to be "garbage collected".
  release: ->
    return unless @cached
    key = @cacheKey()
    @_cache.counts[key]--

  # Cleans up all unreferenced instances.
  reap: ->
    # delete all models with counts == 0
    for key, count of @_cache.counts
      if count < 1
        delete @_cache.store[key]
        delete @_cache.counts[key]

  fetchRelated: (attribute) ->

  # Create a related model.
  #
  # Arguments:
  #
  # * `relaltion` - The relation option (from `relations`)
  # * `attrs` - The attributes on this model.
  _createRelation: (key, relOptions, attrs, options) ->
    # Store reverse relation for collection if specified.
    if relOptions.relation.type is Joints.HasOne
      # If just the ID is passed, then create empty attributes object.
      unless _.isObject(attrs)
        # Try to coerce ID as a number if possible.
        unless (id = Number(attrs))
          id = attrs
        attrs = {id: id}

      isNew = false

      # Check if instance already exists.
      if attrs instanceof Joints.Model
        instance = attrs

      # Not setting model instance, or if model instance ID is different from current.
      if not instance
        instance = new relOptions.relation.relatedModel(attrs)
        isNew = true

      # Create reverse relation for instance.
      # This is for backwards compatibility using `reverseRelation` option.
      if relOptions.reverseRelation
        instance[relOptions.reverseRelation.key] = this

      # If reverseKey is specified, use it.
      # This is the new and preferred way to store reverse relations.
      if relOptions.reverseKey
        instance[relOptions.reverseKey] = this

      # If instance is just created, return it.
      return instance if isNew

      # If the ID has changed then return the new model instance.
      if instance.id isnt @get(key)?.id
        return instance

      # Otherwise just update the attributes of existing instance.
      return instance.set(attrs, options)

    if relOptions.relation.type is Joints.HasMany
      collection = @get key
      # Support a list of numbers (IDs) or a list of objects.
      items = []
      for item in attrs
        if (id = Number(item))
          items.push {id: id}
        else
          items.push item
      collection.reset(items, options)

      # Create reverse relation for collection.
      if relOptions.reverseRelation
        collection[relOptions.reverseRelation.key] = this

      if relOptions.reverseKey
        collection[relOptions.reverseKey] = this

      return collection

    throw new Error("Unsupported relation type specified for #{@constructor.name}")

  # Gets the options for a given model attribute name.
  _getRelationOptions: (attrName) -> @relations?[attrName]

  # Pre-process the
  set: (attr, value, options) ->
    # In the case of unset.
    if options?.unset
        @trigger('bind:' + attr, null, options)  # For stickit data-binding.
        return super

    # Initialize relations properly.
    if _.isObject(attr)
      for k, v of attr
        # If suffixed with `_id` then strip it out.
        idSuffix = '_id'
        if k.slice(k.length - idSuffix.length) is idSuffix
          k = k.substr(0, k.length - idSuffix.length)

        # If this is a related model/collection.
        if (relOptions = @_getRelationOptions(k))
          instance = @_createRelation(k, relOptions, v, options)
          attr[k] = instance

        # If attribute name is appended with `_date` then parse date.
        if k.substr(-5) is '_date' and not _.isDate(v) and v?
          attr[k] = moment(v, 'YYYY-MM-DD').hours(0).minutes(0).seconds(0).toDate()

      # If we're setting the ID attribute
      if 'id' of attr or @idAttribute of attr
        @release()  # Release current cached instance based on ID
        @capture(attr, options)

    # Only setting one attribute.
    else
      # If this is a related model/collection.
      if (relOptions = @_getRelationOptions(attr))
        instance = @_createRelation(attr, relOptions, value, options)
        return super(attr, instance, options)

      # If attribute name is appended with `_date` then parse date.
      if attr.substr(-5) is '_date' and not _.isDate(value) and value?
        value = moment(value, 'YYYY-MM-DD').hours(0).minutes(0).seconds(0).toDate()

      # If we're setting the ID attribute
      if attr is @idAttribute or attr is 'id'
        @release()  # Release current cached instance based on ID
        obj ={}
        obj[attr] = value
        @capture(obj, options)

    return super(attr, value, options)

  get: (attr) ->
    # If value exists, return it.
    if (value = super(attr)) isnt undefined
      return value

    # If HasMany relation is declared but no collection is initialized, then create it.
    if (relOptions = @_getRelationOptions(attr)) and relOptions.relation.type is Joints.HasMany
      clazz = relOptions.relation.collectionType or Backbone.Collection
      collection = new clazz()
      @attributes[attr] = collection

      # Set reverse relation if needed.
      if (relOptions.reverseRelation)
        collection[relOptions.reverseRelation.key] = this

      if (relOptions.reverseKey)
        collection[relOptions.reverseKey] = this

      return collection

  toJSON: ->
    data = super

    # No relations
    return data unless @relations

    # Relational support
    for key, options of @relations
      rel = options.relation

      if rel.type is Joints.HasOne
        model = @attributes[key]
        data[key] = model?.get(rel.includeInJSON) or model?.id or model?[model.idAttribute] or null
      else if rel.type is Joints.HasMany
        # This will always return a collection (even if it has never been set).
        attr = rel.includeInJSON or 'id'
        data[key] = @get(key).pluck(attr)

    return data
