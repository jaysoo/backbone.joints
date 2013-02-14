(function() {
  var Joints,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  Joints = Backbone.Joints = {};

  Joints.HasOne = 'HasOne';

  Joints.HasMany = 'HasMany';

  Joints.hasOne = function(modelClass) {
    return {
      type: Joints.HasOne,
      relatedModel: modelClass
    };
  };

  Joints.hasMany = function(collectionClass) {
    return {
      type: Joints.HasMany,
      collectionType: collectionClass
    };
  };

  Joints.Model = (function(_super) {

    __extends(Model, _super);

    Model.prototype.cache = true;

    function Model(attrs, options) {
      var model, _base;
      if (attrs == null) {
        attrs = {};
      }
      if (options == null) {
        options = {};
      }
      (_base = this.constructor.prototype)._cache || (_base._cache = {
        store: {},
        counts: {}
      });
      if (this.cache && (model = this.capture(attrs))) {
        if (options.collection && !model.collection) {
          model.collection = options.collection;
        }
        return model;
      }
      return Model.__super__.constructor.apply(this, arguments);
    }

    Model.prototype.cacheKey = function(attrs) {
      return this.id || (attrs != null ? attrs[this.idAttribute] : void 0);
    };

    Model.prototype.capture = function(attrs, options) {
      var key, model;
      key = this.cacheKey(attrs);
      if (key == null) {
        this.cached = false;
        return;
      }
      model = this._cache.store[key];
      if (model === this) {
        return this;
      }
      if (model) {
        this._cache.counts[key]++;
        model.set(attrs, options);
        return model;
      }
      this._cache.store[key] = this;
      this._cache.counts[key] = 1;
      this.cached = true;
      return null;
    };

    Model.prototype.release = function() {
      var key;
      if (!this.cached) {
        return;
      }
      key = this.cacheKey();
      return this._cache.counts[key]--;
    };

    Model.prototype.reap = function() {
      var count, key, _ref, _results;
      _ref = this._cache.counts;
      _results = [];
      for (key in _ref) {
        count = _ref[key];
        if (count < 1) {
          delete this._cache.store[key];
          _results.push(delete this._cache.counts[key]);
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    Model.prototype.fetchRelated = function(attribute) {};

    Model.prototype._createRelation = function(key, relOptions, attrs, options) {
      var collection, id, instance, isNew, item, items, _i, _len, _ref;
      if (relOptions.relation.type === Joints.HasOne) {
        if (!_.isObject(attrs)) {
          if (!(id = Number(attrs))) {
            id = attrs;
          }
          attrs = {
            id: id
          };
        }
        isNew = false;
        if (attrs instanceof Joints.Model) {
          instance = attrs;
        }
        if (!instance) {
          instance = new relOptions.relation.relatedModel(attrs);
          isNew = true;
        }
        if (relOptions.reverseRelation) {
          instance[relOptions.reverseRelation.key] = this;
        }
        if (relOptions.reverseKey) {
          instance[relOptions.reverseKey] = this;
        }
        if (isNew) {
          return instance;
        }
        if (instance.id !== ((_ref = this.get(key)) != null ? _ref.id : void 0)) {
          return instance;
        }
        return instance.set(attrs, options);
      }
      if (relOptions.relation.type === Joints.HasMany) {
        collection = this.get(key);
        items = [];
        for (_i = 0, _len = attrs.length; _i < _len; _i++) {
          item = attrs[_i];
          if ((id = Number(item))) {
            items.push({
              id: id
            });
          } else {
            items.push(item);
          }
        }
        collection.reset(items, options);
        if (relOptions.reverseRelation) {
          collection[relOptions.reverseRelation.key] = this;
        }
        if (relOptions.reverseKey) {
          collection[relOptions.reverseKey] = this;
        }
        return collection;
      }
      throw new Error("Unsupported relation type specified for " + this.constructor.name);
    };

    Model.prototype._getRelationOptions = function(attrName) {
      var _ref;
      return (_ref = this.relations) != null ? _ref[attrName] : void 0;
    };

    Model.prototype.set = function(attr, value, options) {
      var idSuffix, instance, k, obj, relOptions, v;
      if (options != null ? options.unset : void 0) {
        this.trigger('bind:' + attr, null, options);
        return Model.__super__.set.apply(this, arguments);
      }
      if (_.isObject(attr)) {
        for (k in attr) {
          v = attr[k];
          idSuffix = '_id';
          if (k.slice(k.length - idSuffix.length) === idSuffix) {
            k = k.substr(0, k.length - idSuffix.length);
          }
          if ((relOptions = this._getRelationOptions(k))) {
            instance = this._createRelation(k, relOptions, v, options);
            attr[k] = instance;
          }
          if (k.substr(-5) === '_date' && !_.isDate(v) && (v != null)) {
            attr[k] = moment(v, 'YYYY-MM-DD').hours(0).minutes(0).seconds(0).toDate();
          }
        }
        if ('id' in attr || this.idAttribute in attr) {
          this.release();
          this.capture(attr, options);
        }
      } else {
        if ((relOptions = this._getRelationOptions(attr))) {
          instance = this._createRelation(attr, relOptions, value, options);
          return Model.__super__.set.call(this, attr, instance, options);
        }
        if (attr.substr(-5) === '_date' && !_.isDate(value) && (value != null)) {
          value = moment(value, 'YYYY-MM-DD').hours(0).minutes(0).seconds(0).toDate();
        }
        if (attr === this.idAttribute || attr === 'id') {
          this.release();
          obj = {};
          obj[attr] = value;
          this.capture(obj, options);
        }
      }
      return Model.__super__.set.call(this, attr, value, options);
    };

    Model.prototype.get = function(attr) {
      var clazz, collection, relOptions, value;
      if ((value = Model.__super__.get.call(this, attr)) !== void 0) {
        return value;
      }
      if ((relOptions = this._getRelationOptions(attr)) && relOptions.relation.type === Joints.HasMany) {
        clazz = relOptions.relation.collectionType || Backbone.Collection;
        collection = new clazz();
        this.attributes[attr] = collection;
        if (relOptions.reverseRelation) {
          collection[relOptions.reverseRelation.key] = this;
        }
        if (relOptions.reverseKey) {
          collection[relOptions.reverseKey] = this;
        }
        return collection;
      }
    };

    Model.prototype.toJSON = function() {
      var attr, data, key, model, options, rel, _ref;
      data = Model.__super__.toJSON.apply(this, arguments);
      if (!this.relations) {
        return data;
      }
      _ref = this.relations;
      for (key in _ref) {
        options = _ref[key];
        rel = options.relation;
        if (rel.type === Joints.HasOne) {
          model = this.attributes[key];
          data[key] = (model != null ? model.get(rel.includeInJSON) : void 0) || (model != null ? model.id : void 0) || (model != null ? model[model.idAttribute] : void 0) || null;
        } else if (rel.type === Joints.HasMany) {
          attr = rel.includeInJSON || 'id';
          data[key] = this.get(key).pluck(attr);
        }
      }
      return data;
    };

    return Model;

  })(Backbone.Model);

}).call(this);
