// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'isar_models.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetAnimeCollectionCollection on Isar {
  IsarCollection<AnimeCollection> get animeCollections => this.collection();
}

const AnimeCollectionSchema = CollectionSchema(
  name: r'AnimeCollection',
  id: -4277085877020617371,
  properties: {
    r'backdropUrl': PropertySchema(
      id: 0,
      name: r'backdropUrl',
      type: IsarType.string,
    ),
    r'coverUrl': PropertySchema(
      id: 1,
      name: r'coverUrl',
      type: IsarType.string,
    ),
    r'episodes': PropertySchema(
      id: 2,
      name: r'episodes',
      type: IsarType.objectList,

      target: r'EpisodeEmbedded',
    ),
    r'genres': PropertySchema(
      id: 3,
      name: r'genres',
      type: IsarType.stringList,
    ),
    r'lastWatchedAt': PropertySchema(
      id: 4,
      name: r'lastWatchedAt',
      type: IsarType.dateTime,
    ),
    r'lastWatchedEpisodeId': PropertySchema(
      id: 5,
      name: r'lastWatchedEpisodeId',
      type: IsarType.string,
    ),
    r'lastWatchedPositionSeconds': PropertySchema(
      id: 6,
      name: r'lastWatchedPositionSeconds',
      type: IsarType.long,
    ),
    r'rating': PropertySchema(id: 7, name: r'rating', type: IsarType.string),
    r'slug': PropertySchema(id: 8, name: r'slug', type: IsarType.string),
    r'sourceUrl': PropertySchema(
      id: 9,
      name: r'sourceUrl',
      type: IsarType.string,
    ),
    r'status': PropertySchema(id: 10, name: r'status', type: IsarType.string),
    r'synopsis': PropertySchema(
      id: 11,
      name: r'synopsis',
      type: IsarType.string,
    ),
    r'title': PropertySchema(id: 12, name: r'title', type: IsarType.string),
    r'updatedAt': PropertySchema(
      id: 13,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'year': PropertySchema(id: 14, name: r'year', type: IsarType.string),
  },

  estimateSize: _animeCollectionEstimateSize,
  serialize: _animeCollectionSerialize,
  deserialize: _animeCollectionDeserialize,
  deserializeProp: _animeCollectionDeserializeProp,
  idName: r'id',
  indexes: {
    r'slug': IndexSchema(
      id: 6169444064746062836,
      name: r'slug',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'slug',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {r'EpisodeEmbedded': EpisodeEmbeddedSchema},

  getId: _animeCollectionGetId,
  getLinks: _animeCollectionGetLinks,
  attach: _animeCollectionAttach,
  version: '3.4.1',
);

int _animeCollectionEstimateSize(
  AnimeCollection object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.backdropUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.coverUrl.length * 3;
  bytesCount += 3 + object.episodes.length * 3;
  {
    final offsets = allOffsets[EpisodeEmbedded]!;
    for (var i = 0; i < object.episodes.length; i++) {
      final value = object.episodes[i];
      bytesCount += EpisodeEmbeddedSchema.estimateSize(
        value,
        offsets,
        allOffsets,
      );
    }
  }
  bytesCount += 3 + object.genres.length * 3;
  {
    for (var i = 0; i < object.genres.length; i++) {
      final value = object.genres[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.lastWatchedEpisodeId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.rating;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.slug.length * 3;
  {
    final value = object.sourceUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.status;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.synopsis;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  {
    final value = object.year;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _animeCollectionSerialize(
  AnimeCollection object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.backdropUrl);
  writer.writeString(offsets[1], object.coverUrl);
  writer.writeObjectList<EpisodeEmbedded>(
    offsets[2],
    allOffsets,
    EpisodeEmbeddedSchema.serialize,
    object.episodes,
  );
  writer.writeStringList(offsets[3], object.genres);
  writer.writeDateTime(offsets[4], object.lastWatchedAt);
  writer.writeString(offsets[5], object.lastWatchedEpisodeId);
  writer.writeLong(offsets[6], object.lastWatchedPositionSeconds);
  writer.writeString(offsets[7], object.rating);
  writer.writeString(offsets[8], object.slug);
  writer.writeString(offsets[9], object.sourceUrl);
  writer.writeString(offsets[10], object.status);
  writer.writeString(offsets[11], object.synopsis);
  writer.writeString(offsets[12], object.title);
  writer.writeDateTime(offsets[13], object.updatedAt);
  writer.writeString(offsets[14], object.year);
}

AnimeCollection _animeCollectionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AnimeCollection();
  object.backdropUrl = reader.readStringOrNull(offsets[0]);
  object.coverUrl = reader.readString(offsets[1]);
  object.episodes =
      reader.readObjectList<EpisodeEmbedded>(
        offsets[2],
        EpisodeEmbeddedSchema.deserialize,
        allOffsets,
        EpisodeEmbedded(),
      ) ??
      [];
  object.genres = reader.readStringList(offsets[3]) ?? [];
  object.id = id;
  object.lastWatchedAt = reader.readDateTimeOrNull(offsets[4]);
  object.lastWatchedEpisodeId = reader.readStringOrNull(offsets[5]);
  object.lastWatchedPositionSeconds = reader.readLongOrNull(offsets[6]);
  object.rating = reader.readStringOrNull(offsets[7]);
  object.slug = reader.readString(offsets[8]);
  object.sourceUrl = reader.readStringOrNull(offsets[9]);
  object.status = reader.readStringOrNull(offsets[10]);
  object.synopsis = reader.readStringOrNull(offsets[11]);
  object.title = reader.readString(offsets[12]);
  object.updatedAt = reader.readDateTime(offsets[13]);
  object.year = reader.readStringOrNull(offsets[14]);
  return object;
}

P _animeCollectionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readObjectList<EpisodeEmbedded>(
                offset,
                EpisodeEmbeddedSchema.deserialize,
                allOffsets,
                EpisodeEmbedded(),
              ) ??
              [])
          as P;
    case 3:
      return (reader.readStringList(offset) ?? []) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readLongOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readDateTime(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _animeCollectionGetId(AnimeCollection object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _animeCollectionGetLinks(AnimeCollection object) {
  return [];
}

void _animeCollectionAttach(
  IsarCollection<dynamic> col,
  Id id,
  AnimeCollection object,
) {
  object.id = id;
}

extension AnimeCollectionByIndex on IsarCollection<AnimeCollection> {
  Future<AnimeCollection?> getBySlug(String slug) {
    return getByIndex(r'slug', [slug]);
  }

  AnimeCollection? getBySlugSync(String slug) {
    return getByIndexSync(r'slug', [slug]);
  }

  Future<bool> deleteBySlug(String slug) {
    return deleteByIndex(r'slug', [slug]);
  }

  bool deleteBySlugSync(String slug) {
    return deleteByIndexSync(r'slug', [slug]);
  }

  Future<List<AnimeCollection?>> getAllBySlug(List<String> slugValues) {
    final values = slugValues.map((e) => [e]).toList();
    return getAllByIndex(r'slug', values);
  }

  List<AnimeCollection?> getAllBySlugSync(List<String> slugValues) {
    final values = slugValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'slug', values);
  }

  Future<int> deleteAllBySlug(List<String> slugValues) {
    final values = slugValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'slug', values);
  }

  int deleteAllBySlugSync(List<String> slugValues) {
    final values = slugValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'slug', values);
  }

  Future<Id> putBySlug(AnimeCollection object) {
    return putByIndex(r'slug', object);
  }

  Id putBySlugSync(AnimeCollection object, {bool saveLinks = true}) {
    return putByIndexSync(r'slug', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllBySlug(List<AnimeCollection> objects) {
    return putAllByIndex(r'slug', objects);
  }

  List<Id> putAllBySlugSync(
    List<AnimeCollection> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'slug', objects, saveLinks: saveLinks);
  }
}

extension AnimeCollectionQueryWhereSort
    on QueryBuilder<AnimeCollection, AnimeCollection, QWhere> {
  QueryBuilder<AnimeCollection, AnimeCollection, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AnimeCollectionQueryWhere
    on QueryBuilder<AnimeCollection, AnimeCollection, QWhereClause> {
  QueryBuilder<AnimeCollection, AnimeCollection, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterWhereClause> slugEqualTo(
    String slug,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'slug', value: [slug]),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterWhereClause>
  slugNotEqualTo(String slug) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'slug',
                lower: [],
                upper: [slug],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'slug',
                lower: [slug],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'slug',
                lower: [slug],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'slug',
                lower: [],
                upper: [slug],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension AnimeCollectionQueryFilter
    on QueryBuilder<AnimeCollection, AnimeCollection, QFilterCondition> {
  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  backdropUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'backdropUrl'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  backdropUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'backdropUrl'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  backdropUrlEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'backdropUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  backdropUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'backdropUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  backdropUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'backdropUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  backdropUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'backdropUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  backdropUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'backdropUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  backdropUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'backdropUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  backdropUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'backdropUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  backdropUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'backdropUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  backdropUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'backdropUrl', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  backdropUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'backdropUrl', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  coverUrlEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'coverUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  coverUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'coverUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  coverUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'coverUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  coverUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'coverUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  coverUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'coverUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  coverUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'coverUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  coverUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'coverUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  coverUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'coverUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  coverUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'coverUrl', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  coverUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'coverUrl', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  episodesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'episodes', length, true, length, true);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  episodesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'episodes', 0, true, 0, true);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  episodesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'episodes', 0, false, 999999, true);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  episodesLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'episodes', 0, true, length, include);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  episodesLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'episodes', length, include, 999999, true);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  episodesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'episodes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'genres',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'genres',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'genres',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'genres',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'genres',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'genres',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'genres',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'genres',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'genres', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'genres', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'genres', length, true, length, true);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'genres', 0, true, 0, true);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'genres', 0, false, 999999, true);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'genres', 0, true, length, include);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'genres', length, include, 999999, true);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  genresLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'genres',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastWatchedAt'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastWatchedAt'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastWatchedAt', value: value),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastWatchedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastWatchedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastWatchedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedEpisodeIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastWatchedEpisodeId'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedEpisodeIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastWatchedEpisodeId'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedEpisodeIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastWatchedEpisodeId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedEpisodeIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastWatchedEpisodeId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedEpisodeIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastWatchedEpisodeId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedEpisodeIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastWatchedEpisodeId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedEpisodeIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lastWatchedEpisodeId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedEpisodeIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lastWatchedEpisodeId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedEpisodeIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lastWatchedEpisodeId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedEpisodeIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lastWatchedEpisodeId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedEpisodeIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastWatchedEpisodeId', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedEpisodeIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'lastWatchedEpisodeId',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedPositionSecondsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastWatchedPositionSeconds'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedPositionSecondsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(
          property: r'lastWatchedPositionSeconds',
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedPositionSecondsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastWatchedPositionSeconds',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedPositionSecondsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastWatchedPositionSeconds',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedPositionSecondsLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastWatchedPositionSeconds',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  lastWatchedPositionSecondsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastWatchedPositionSeconds',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  ratingIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'rating'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  ratingIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'rating'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  ratingEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'rating',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  ratingGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'rating',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  ratingLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'rating',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  ratingBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'rating',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  ratingStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'rating',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  ratingEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'rating',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  ratingContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'rating',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  ratingMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'rating',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  ratingIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'rating', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  ratingIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'rating', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  slugEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'slug',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  slugGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'slug',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  slugLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'slug',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  slugBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'slug',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  slugStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'slug',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  slugEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'slug',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  slugContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'slug',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  slugMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'slug',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  slugIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'slug', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  slugIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'slug', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  sourceUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sourceUrl'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  sourceUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sourceUrl'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  sourceUrlEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sourceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  sourceUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  sourceUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  sourceUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  sourceUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sourceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  sourceUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sourceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  sourceUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sourceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  sourceUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sourceUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  sourceUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceUrl', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  sourceUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sourceUrl', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  statusIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'status'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  statusIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'status'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  statusEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  statusGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  statusLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  statusBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'status',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  statusStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  statusEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'status',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  synopsisIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'synopsis'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  synopsisIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'synopsis'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  synopsisEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'synopsis',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  synopsisGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'synopsis',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  synopsisLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'synopsis',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  synopsisBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'synopsis',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  synopsisStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'synopsis',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  synopsisEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'synopsis',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  synopsisContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'synopsis',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  synopsisMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'synopsis',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  synopsisIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'synopsis', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  synopsisIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'synopsis', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  titleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  titleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  titleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  updatedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  yearIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'year'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  yearIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'year'),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  yearEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'year',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  yearGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'year',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  yearLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'year',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  yearBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'year',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  yearStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'year',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  yearEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'year',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  yearContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'year',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  yearMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'year',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  yearIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'year', value: ''),
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  yearIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'year', value: ''),
      );
    });
  }
}

extension AnimeCollectionQueryObject
    on QueryBuilder<AnimeCollection, AnimeCollection, QFilterCondition> {
  QueryBuilder<AnimeCollection, AnimeCollection, QAfterFilterCondition>
  episodesElement(FilterQuery<EpisodeEmbedded> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'episodes');
    });
  }
}

extension AnimeCollectionQueryLinks
    on QueryBuilder<AnimeCollection, AnimeCollection, QFilterCondition> {}

extension AnimeCollectionQuerySortBy
    on QueryBuilder<AnimeCollection, AnimeCollection, QSortBy> {
  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByBackdropUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backdropUrl', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByBackdropUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backdropUrl', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByCoverUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverUrl', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByCoverUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverUrl', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByLastWatchedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastWatchedAt', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByLastWatchedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastWatchedAt', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByLastWatchedEpisodeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastWatchedEpisodeId', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByLastWatchedEpisodeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastWatchedEpisodeId', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByLastWatchedPositionSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastWatchedPositionSeconds', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByLastWatchedPositionSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastWatchedPositionSeconds', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy> sortByRating() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rating', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByRatingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rating', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy> sortBySlug() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'slug', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortBySlugDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'slug', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortBySourceUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceUrl', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortBySourceUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceUrl', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortBySynopsis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synopsis', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortBySynopsisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synopsis', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy> sortByYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  sortByYearDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.desc);
    });
  }
}

extension AnimeCollectionQuerySortThenBy
    on QueryBuilder<AnimeCollection, AnimeCollection, QSortThenBy> {
  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByBackdropUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backdropUrl', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByBackdropUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backdropUrl', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByCoverUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverUrl', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByCoverUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverUrl', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByLastWatchedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastWatchedAt', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByLastWatchedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastWatchedAt', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByLastWatchedEpisodeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastWatchedEpisodeId', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByLastWatchedEpisodeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastWatchedEpisodeId', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByLastWatchedPositionSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastWatchedPositionSeconds', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByLastWatchedPositionSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastWatchedPositionSeconds', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy> thenByRating() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rating', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByRatingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rating', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy> thenBySlug() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'slug', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenBySlugDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'slug', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenBySourceUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceUrl', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenBySourceUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceUrl', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenBySynopsis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synopsis', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenBySynopsisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synopsis', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy> thenByYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.asc);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QAfterSortBy>
  thenByYearDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.desc);
    });
  }
}

extension AnimeCollectionQueryWhereDistinct
    on QueryBuilder<AnimeCollection, AnimeCollection, QDistinct> {
  QueryBuilder<AnimeCollection, AnimeCollection, QDistinct>
  distinctByBackdropUrl({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'backdropUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QDistinct> distinctByCoverUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'coverUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QDistinct> distinctByGenres() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'genres');
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QDistinct>
  distinctByLastWatchedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastWatchedAt');
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QDistinct>
  distinctByLastWatchedEpisodeId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'lastWatchedEpisodeId',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QDistinct>
  distinctByLastWatchedPositionSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastWatchedPositionSeconds');
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QDistinct> distinctByRating({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rating', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QDistinct> distinctBySlug({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'slug', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QDistinct>
  distinctBySourceUrl({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QDistinct> distinctByStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QDistinct> distinctBySynopsis({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'synopsis', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QDistinct> distinctByTitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<AnimeCollection, AnimeCollection, QDistinct> distinctByYear({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'year', caseSensitive: caseSensitive);
    });
  }
}

extension AnimeCollectionQueryProperty
    on QueryBuilder<AnimeCollection, AnimeCollection, QQueryProperty> {
  QueryBuilder<AnimeCollection, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AnimeCollection, String?, QQueryOperations>
  backdropUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'backdropUrl');
    });
  }

  QueryBuilder<AnimeCollection, String, QQueryOperations> coverUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'coverUrl');
    });
  }

  QueryBuilder<AnimeCollection, List<EpisodeEmbedded>, QQueryOperations>
  episodesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'episodes');
    });
  }

  QueryBuilder<AnimeCollection, List<String>, QQueryOperations>
  genresProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'genres');
    });
  }

  QueryBuilder<AnimeCollection, DateTime?, QQueryOperations>
  lastWatchedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastWatchedAt');
    });
  }

  QueryBuilder<AnimeCollection, String?, QQueryOperations>
  lastWatchedEpisodeIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastWatchedEpisodeId');
    });
  }

  QueryBuilder<AnimeCollection, int?, QQueryOperations>
  lastWatchedPositionSecondsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastWatchedPositionSeconds');
    });
  }

  QueryBuilder<AnimeCollection, String?, QQueryOperations> ratingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rating');
    });
  }

  QueryBuilder<AnimeCollection, String, QQueryOperations> slugProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'slug');
    });
  }

  QueryBuilder<AnimeCollection, String?, QQueryOperations> sourceUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceUrl');
    });
  }

  QueryBuilder<AnimeCollection, String?, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<AnimeCollection, String?, QQueryOperations> synopsisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'synopsis');
    });
  }

  QueryBuilder<AnimeCollection, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<AnimeCollection, DateTime, QQueryOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<AnimeCollection, String?, QQueryOperations> yearProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'year');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

const EpisodeEmbeddedSchema = Schema(
  name: r'EpisodeEmbedded',
  id: 1826561165318494916,
  properties: {
    r'duration': PropertySchema(
      id: 0,
      name: r'duration',
      type: IsarType.string,
    ),
    r'episodeNumber': PropertySchema(
      id: 1,
      name: r'episodeNumber',
      type: IsarType.double,
    ),
    r'id': PropertySchema(id: 2, name: r'id', type: IsarType.string),
    r'pageUrl': PropertySchema(id: 3, name: r'pageUrl', type: IsarType.string),
    r'streamUrl': PropertySchema(
      id: 4,
      name: r'streamUrl',
      type: IsarType.string,
    ),
    r'thumbnailUrl': PropertySchema(
      id: 5,
      name: r'thumbnailUrl',
      type: IsarType.string,
    ),
    r'title': PropertySchema(id: 6, name: r'title', type: IsarType.string),
  },

  estimateSize: _episodeEmbeddedEstimateSize,
  serialize: _episodeEmbeddedSerialize,
  deserialize: _episodeEmbeddedDeserialize,
  deserializeProp: _episodeEmbeddedDeserializeProp,
);

int _episodeEmbeddedEstimateSize(
  EpisodeEmbedded object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.duration;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.id;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.pageUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.streamUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.thumbnailUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.title;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _episodeEmbeddedSerialize(
  EpisodeEmbedded object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.duration);
  writer.writeDouble(offsets[1], object.episodeNumber);
  writer.writeString(offsets[2], object.id);
  writer.writeString(offsets[3], object.pageUrl);
  writer.writeString(offsets[4], object.streamUrl);
  writer.writeString(offsets[5], object.thumbnailUrl);
  writer.writeString(offsets[6], object.title);
}

EpisodeEmbedded _episodeEmbeddedDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EpisodeEmbedded();
  object.duration = reader.readStringOrNull(offsets[0]);
  object.episodeNumber = reader.readDoubleOrNull(offsets[1]);
  object.id = reader.readStringOrNull(offsets[2]);
  object.pageUrl = reader.readStringOrNull(offsets[3]);
  object.streamUrl = reader.readStringOrNull(offsets[4]);
  object.thumbnailUrl = reader.readStringOrNull(offsets[5]);
  object.title = reader.readStringOrNull(offsets[6]);
  return object;
}

P _episodeEmbeddedDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readDoubleOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension EpisodeEmbeddedQueryFilter
    on QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QFilterCondition> {
  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  durationIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'duration'),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  durationIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'duration'),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  durationEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'duration',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  durationGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'duration',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  durationLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'duration',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  durationBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'duration',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  durationStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'duration',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  durationEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'duration',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  durationContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'duration',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  durationMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'duration',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  durationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'duration', value: ''),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  durationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'duration', value: ''),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  episodeNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'episodeNumber'),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  episodeNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'episodeNumber'),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  episodeNumberEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'episodeNumber',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  episodeNumberGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'episodeNumber',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  episodeNumberLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'episodeNumber',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  episodeNumberBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'episodeNumber',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  idEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  idGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  idLessThan(String? value, {bool include = false, bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  idBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  idStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  idEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  idContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  idMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  pageUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'pageUrl'),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  pageUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'pageUrl'),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  pageUrlEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'pageUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  pageUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'pageUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  pageUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'pageUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  pageUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'pageUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  pageUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'pageUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  pageUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'pageUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  pageUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'pageUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  pageUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'pageUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  pageUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pageUrl', value: ''),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  pageUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'pageUrl', value: ''),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  streamUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'streamUrl'),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  streamUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'streamUrl'),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  streamUrlEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'streamUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  streamUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'streamUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  streamUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'streamUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  streamUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'streamUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  streamUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'streamUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  streamUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'streamUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  streamUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'streamUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  streamUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'streamUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  streamUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'streamUrl', value: ''),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  streamUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'streamUrl', value: ''),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  thumbnailUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'thumbnailUrl'),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  thumbnailUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'thumbnailUrl'),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  thumbnailUrlEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'thumbnailUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  thumbnailUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'thumbnailUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  thumbnailUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'thumbnailUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  thumbnailUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'thumbnailUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  thumbnailUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'thumbnailUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  thumbnailUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'thumbnailUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  thumbnailUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'thumbnailUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  thumbnailUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'thumbnailUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  thumbnailUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'thumbnailUrl', value: ''),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  thumbnailUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'thumbnailUrl', value: ''),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  titleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'title'),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  titleIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'title'),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  titleEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  titleGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  titleLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  titleBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  titleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  titleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QAfterFilterCondition>
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }
}

extension EpisodeEmbeddedQueryObject
    on QueryBuilder<EpisodeEmbedded, EpisodeEmbedded, QFilterCondition> {}
