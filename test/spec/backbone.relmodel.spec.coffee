describe 'Backbone.Joints', ->

  describe 'Model Tests', ->
    # Classes for testing.

    class Faz extends Backbone.Joints.Model
      constructor: -> return super

    class Fazzes extends Backbone.Collection
      model: Faz

    class Bar extends Backbone.Joints.Model
      constructor: -> return super

      relations:
        faz:
          relation: Backbone.Joints.hasOne(Faz)
          reverseKey: 'bar'

    class Bars extends Backbone.Collection
      model: Bar

    class Foo extends Backbone.Joints.Model
      constructor: -> return super

      url: '/foos/'

      relations:
        bars:
          relation: Backbone.Joints.hasMany(Bars)
          reverseKey: 'foo'

    beforeEach ->
      @server = sinon.fakeServer.create()
      @server.respondWith(
        'POST', '/foos/',
        [201, { 'Content-Type': 'application/json' },
        '{}']);

    afterEach ->
      @server.restore()

    describe 'Instance Cache', ->
      describe 'when two new models have no IDs', ->
        it 'should not return same instance twice', ->
          faz1 = new Faz(name: 'A')
          faz2 = new Faz(name: 'B')
          expect(faz1).to.not.equal faz2

      describe 'when a model is newed twice with same ID', ->
        it 'should return the same instance with merged attributes', ->
          id = Number _.uniqueId()
          faz1 = new Faz(id: id, name: 'A')
          faz2 = new Faz(id: id, name: 'B')

          # Instances are the same.
          expect(faz1).to.equal faz2

          # `name` is now updated to `B` on hte instance.
          expect(faz1.get('name')).to.equal 'B'
          expect(faz2.get('name')).to.equal 'B'

      describe 'when a newed model has its ID set after instantiation', ->
        it 'should update the instance cache for that prototype', ->
          # Check .set({id: id}) style
          cache = Faz::_cache
          faz = new Faz(name: 'A')
          id = Number _.uniqueId()
          expect(cache[id]).to.be.undefined
          faz.set {id: id}
          expect(cache.store[id]).to.equal faz

          # Check .set('id', id) style
          cache = Faz::_cache
          faz2 = new Faz(name: 'B')
          id = Number _.uniqueId()
          expect(cache[id]).to.be.undefined
          faz2.set 'id', id
          expect(cache.store[id]).to.equal faz2

      describe 'when two collections share common model IDs', ->
        it 'should hold the same instance for the same IDs', ->
          id1 = Number _.uniqueId()
          id2 = Number _.uniqueId()
          id3 = Number _.uniqueId()
          id4 = Number _.uniqueId()
          id5 = Number _.uniqueId()

          col1 = new Fazzes([
            {id: id1}
            {id: id2}
            {id: id4}
          ])

          col2 = new Fazzes([
            {id: id2}
            {id: id3}
            {id: id4}
            {id: id5}
          ])

          # Check instances are same.
          expect(col1.at(1)).to.equal col2.at(0)
          expect(col1.at(2)).to.equal col2.at(2)


    describe 'Relational Support', ->
      it 'should initialize an empty related collection if data is not passed', ->
        foo = new Foo()
        expect(foo.get('bars')).to.be.defined
        expect(foo.get('bars')).to.be.instanceOf Bars

      it 'should initialize populated collection if data passed', ->
        bars = [
          {id: Number(_.uniqueId())}
          {id: Number(_.uniqueId())}
          {id: Number(_.uniqueId())}
        ]
        foo = new Foo(bars: bars)

        expect(foo.get('bars').length).to.equal 3
        expect(foo.get('bars').pluck('id')).to.eql _.pluck(bars, 'id')

      it 'should initialize related model if the ID is passed as a Number', ->
        id = Number _.uniqueId()
        bar = new Bar(faz: id)
        expect(bar.get('faz')).to.be.instanceOf Faz
        expect(bar.get('faz').id).to.equal id

      it 'should initialize related model if the ID is passed with `_id` suffix', ->
        id = Number _.uniqueId()
        bar = new Bar(faz_id: id)
        expect(bar.get('faz')).to.be.instanceOf Faz
        expect(bar.get('faz').id).to.equal id

      it 'should not expand relations when serialized', ->
        # HasOne relation
        barId = Number _.uniqueId()
        fazId = Number _.uniqueId()
        bar = new Bar(id: barId, faz: fazId)
        data = bar.toJSON()

        # No need to check these.
        delete data.cid
        delete data.dirty

        expected =
          id: barId
          faz: fazId

        expect(data).to.eql expected

        # HasMany relation
        fooId = Number _.uniqueId()
        bars = [
          {id: Number(_.uniqueId())}
          {id: Number(_.uniqueId())}
          {id: Number(_.uniqueId())}
        ]
        foo = new Foo(id: fooId, bars: bars)
        data = foo.toJSON()
        delete data.cid
        delete data.dirty

        expected =
          id: fooId
          bars: _.pluck(bars, 'id')

        expect(data).to.eql expected


      describe 'when a HasMany relation is reset', ->
        it 'should update the collection with new instance', ->
          fooId = Number _.uniqueId()
          bars1 = [
            {id: Number(_.uniqueId()), name: 'A'}
            {id: Number(_.uniqueId()), name: 'B'}
            {id: Number(_.uniqueId()), name: 'C'}
          ]
          bars2 = [
            {id: bars1[0].id, name: 'D'}  # Existing instance!
            {id: Number(_.uniqueId()), name: 'E'}
            {id: Number(_.uniqueId()), name: 'F'}
          ]

          foo = new Foo(id: fooId, bars: bars1)

          barsOriginal = foo.get 'bars'
          instance1 = barsOriginal.at 0

          # Reset collection.
          foo.set('bars', bars2)

          barsNew = foo.get 'bars'

          expect(barsOriginal).to.equal barsNew
          expect(barsNew.length).to.equal 3
          expect(barsNew.at(0)).to.equal instance1
          expect(barsNew.at(0).get('name')).to.equal 'D'
          expect(barsNew.at(1).get('name')).to.equal 'E'
          expect(barsNew.at(2).get('name')).to.equal 'F'


      describe 'when a HasOne relation is set with same ID', ->
        it 'should update the same instance with new attributes', ->
          barId = Number _.uniqueId()
          faz1 = {id: Number(_.uniqueId()), name: 'W'}
          faz2 = {id: faz1.id, name: 'X'}
          bar = new Bar(id: barId, faz: faz1)

          # Check for change event calls.
          spy = sinon.spy()
          bar.on 'change:faz', spy

          instance1 = bar.get('faz')
          expect(instance1.get('name')).to.equal 'W'

          # Set again with same ID.
          bar.set('faz', faz2)
          instance2 = bar.get('faz')
          expect(instance2).to.equal instance1  # Check same instance
          expect(instance2.get('name')).to.equal 'X'
          expect(spy.called).to.be.false  # Still same instance


      describe 'when a HasOne relation is set with different ID', ->
        it 'should set new instance and trigger change event', ->
          barId = Number _.uniqueId()
          faz1 = {id: Number(_.uniqueId()), name: 'W'}
          faz2 = {id: Number(_.uniqueId()), name: 'X'}
          bar = new Bar(id: barId, faz: faz1)

          # Check for change event calls.
          spy1 = sinon.spy()
          spy2 = sinon.spy()
          bar.on 'change', spy1
          bar.on 'change:faz', spy2

          instance1 = bar.get('faz')
          expect(instance1.get('name')).to.equal 'W'

          # Set again with same ID.
          bar.set('faz', faz2)
          instance2 = bar.get('faz')
          expect(instance2).to.not.equal instance1  # Check same instance
          expect(instance2.get('name')).to.equal 'X'
          expect(spy1.calledOnce).to.be.true
          expect(spy2.calledOnce).to.be.true

          # If {silent: true} do not trigger change event!
          bar.set('faz', faz1, {silent: true})
          bar.set({faz: faz1}, {silent: true})
          expect(spy1.calledOnce).to.be.true  # Still only called once
          expect(spy2.calledOnce).to.be.true  # Still only called once

      describe 'when a HasOne relation is set with a model instance', ->
        it 'should set that instance as the relation', ->
          barId = Number _.uniqueId()
          faz1 = new Faz(id: Number(_.uniqueId()), name: 'Y')
          faz2 = new Faz(id: faz1.id, name: 'Z')

          bar = new Bar(id: barId)

          # Check for change event calls.
          spy = sinon.spy()
          bar.on 'change', spy

          # Set again with same ID.
          bar.set('faz', faz2)
          instance2 = bar.get('faz')
          expect(instance2.get('name')).to.equal 'Z'
          expect(spy.calledOnce).to.be.true  # Still same instance

          # Set name back to `Y`
          bar.set('faz', {id: faz1.id, name: 'Y'})
          expect(bar.get('faz').get('name')).to.equal 'Y'
          # All instances are the same
          expect(bar.get('faz')).to.equal instance2
          expect(spy.calledOnce).to.be.true  # Still same instance


      describe 'when a HasOne relation is set with a different model instance', ->
        it 'should set new instance and trigger change event', ->
          barId = Number _.uniqueId()
          faz1 = new Faz(id: Number(_.uniqueId()), name: 'Y')
          faz2 = new Faz(id: Number(_.uniqueId()), name: 'Z')

          bar = new Bar(id: barId, faz: faz1)

          # Check for change event calls.
          spy1 = sinon.spy()
          spy2 = sinon.spy()
          bar.on 'change', spy1
          bar.on 'change:faz', spy2

          instance1 = bar.get('faz')

          # Set again with same ID.
          bar.set('faz', faz2)
          instance2 = bar.get('faz')
          expect(instance2).to.not.equal instance1  # Check same instance
          expect(instance2.get('name')).to.equal 'Z'
          expect(spy1.calledOnce).to.be.true  # Still same instance
          expect(spy2.calledOnce).to.be.true  # Still same instance

          # If {silent: true} do not trigger change event!
          bar.set('faz', faz1, {silent: true})
          bar.set({faz: faz1}, {silent: true})
          expect(spy1.calledOnce).to.be.true  # Still only called once
          expect(spy2.calledOnce).to.be.true  # Still only called once


      describe 'when adding a model with no ID to a collection', ->
        it 'should not create a new instance in collection', ->
          barId = Number _.uniqueId()
          faz = new Faz(name: 'Y')

          bar = new Bar(id: barId)
          bar.set('faz', faz)

          expect(bar.get('faz')).to.equal faz


      describe 'toJSON', ->
        describe 'when a HasOne relation is undefined or has no ID', ->
          it 'should serialize as null', ->
            barId = Number _.uniqueId()
            faz = new Faz(name: 'Y')
            bar = new Bar(id: barId, faz: faz)

            data = bar.toJSON()
            expect(data.faz).to.be.null

            bar.unset('faz')
            data = bar.toJSON()
            expect(data.faz).to.be.null

        describe 'when includeInJSON is set', ->
          it 'should return that attribute instead of id when relation is HasOne', ->
            barId = Number _.uniqueId()
            fazId = Number _.uniqueId()
            faz = new Faz(name: 'Y', id: fazId)
            bar = new Bar(id: barId, faz: faz)
            bar.relations[0].includeInJSON = 'name'

            data = bar.toJSON()
            expect(data.faz).to.equal 'Y'
            bar.unset('faz')
            data = bar.toJSON()
            expect(data.faz).to.be.null
          it 'should return the attribute of each member of the collection in HasMany', ->
            bar1 = new Bar(name: 'bar1')
            bar2 = new Bar(name: 'bar2')
            foo = new Foo(bars: [bar1, bar2])
            foo.relations[0].includeInJSON = 'name'

            data = foo.toJSON()
            expect(data.bars).to.eql ['bar1', 'bar2']

        describe 'when a HasMany relation is not set', ->
          it 'should serialize as an empty array', ->
            foo = new Foo()
            data = foo.toJSON()
            expect(data.bars).to.eql []

      describe 'Collection', ->
        describe 'when a related model is added to a collection', ->
          it 'should set the collection reference', ->
            barId = Number _.uniqueId()
            bar = new Bar(id: barId)
            foo = new Foo()
            bars = foo.get('bars')
            bars.add(bar)
            expect(bar.collection).to.equal bars

            bars.reset([{id: barId}])
            expect(bar.collection).to.equal bars
            expect(bars.at(0).collection).to.equal bars

            bar2Id = Number _.uniqueId()
            bar2 = new Bar(id: bar2Id)
            bars.add({id: bar2Id})
            expect(bar2.collection).to.equal bars

            bar3Id = Number _.uniqueId()
            bar3 = new Bar(id: bar3Id)
            foo.set(bars: [{id: bar3Id}])
            expect(bar3.collection).to.equal bars

      describe 'Reverse relations', ->
        describe 'when a reverse relation is on HasOne relation', ->
          it 'should set the reverse relation on the model using the key specified', ->
            bar = new Bar(id: Number(_.uniqueId()))
            faz = new Faz(id: Number(_.uniqueId()))

            bar.set('faz', faz)
            expect(faz.bar).to.equal bar

        describe 'when a reverse relation is on HasMany relation', ->
          it 'should set the reverse relation on the collection using the key specified', ->
            foo = new Foo(id: Number(_.uniqueId()))
            bars = foo.get('bars')
            expect(bars.foo).to.equal foo
