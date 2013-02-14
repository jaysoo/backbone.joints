# Backbone.Joints

> Light-weight relational plugin Backbone


## Usage

    var Book = Backbone.Joints.Model.extend({
      defaults: {
        available: true
      }
    });

    var Books = Backbone.Collection.extend({
      model: Book
    });

    var Library = Backbone.Joints.Model.extend({
      relations: {
        books: {
          relation: Backbone.Joints.hasMany(Books),
          // Allows us to do `books.library`
          reverseKey: 'library'
        }
      }
    });


    // Create instances
    var books = new Books([
      {
        id: 1,
        title: "The Hitchhiker's Guide to the Galaxy",
        author: 'Douglas Adams'
      },
      {
        id: 2,
        title: 'The Restaurant at the End of the Universe',
        author: 'Douglas Adams'
      },
      {
        id: 3,
        title: 'Life, the Universe and Everything',
        author: 'Douglas Adams'
      }
    ]);

    var library = new Library({
      name: 'Toronto Reference Library',
      books: [1, 2, 3]
    });


    library.get('books').at(0).get('title'); // The Hitchhiker's Guide to the Galaxy


    var book2 = new Book({id: 2}); // ID 2 is in instance cache already
    book2.get('title'); // The Restaurant at the End of the Universe


    // Change the title of a cached instance
    var book3 = new Book({id: 3});
    book3.set('title', 'Mostly Harmless');

    // The cached instance in library's book collection is updated.
    library.get('books').at(2).get('title'); // Mostly Harmless


## Release History

- 2013-02-14 -- v1.0.0-rc.1 -- Initial release

