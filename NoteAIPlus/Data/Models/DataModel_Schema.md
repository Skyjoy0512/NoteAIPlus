# Core Data Schema Definition

This document describes the Core Data model schema for NoteAI Plus. The actual `.xcdatamodeld` file should be created in Xcode with these specifications.

## Entities and Attributes

### RecordingEntity

| Attribute | Type | Optional | Default |
|-----------|------|----------|---------|
| id | UUID | No | - |
| title | String | No | - |
| date | Date | No | - |
| duration | Double | No | 0.0 |
| audioFileURLString | String | No | - |
| transcription | String | Yes | nil |
| whisperModel | String | No | "base" |
| language | String | No | "ja" |
| isFromLimitless | Boolean | No | false |
| createdAt | Date | No | - |
| updatedAt | Date | No | - |

**Relationships:**
- speakers: To-many → SpeakerEntity (Delete Rule: Cascade)
- summaries: To-many → SummaryEntity (Delete Rule: Cascade)
- tags: To-many → TagEntity (Delete Rule: Nullify)

**Indexes:**
- date (for date range queries)
- title (for text search)
- whisperModel (for filtering)

### SpeakerEntity

| Attribute | Type | Optional | Default |
|-----------|------|----------|---------|
| id | UUID | No | - |
| name | String | No | "話者" |
| recordingId | UUID | No | - |
| voiceCharacteristics | Transformable (Dictionary) | Yes | nil |
| voiceEmbedding | Transformable (Array) | Yes | nil |
| voiceConfidence | Float | No | 0.0 |
| createdAt | Date | No | - |
| updatedAt | Date | No | - |

**Relationships:**
- recording: To-one → RecordingEntity (Delete Rule: Nullify)
- segments: To-many → SpeechSegmentEntity (Delete Rule: Cascade)

### SpeechSegmentEntity

| Attribute | Type | Optional | Default |
|-----------|------|----------|---------|
| id | UUID | No | - |
| startTime | Double | No | 0.0 |
| endTime | Double | No | 0.0 |
| text | String | No | - |
| confidence | Float | No | 0.0 |
| speakerId | UUID | No | - |

**Relationships:**
- speaker: To-one → SpeakerEntity (Delete Rule: Nullify)

### SummaryEntity

| Attribute | Type | Optional | Default |
|-----------|------|----------|---------|
| id | UUID | No | - |
| sourceId | UUID | No | - |
| sourceTypeString | String | No | - |
| summaryTypeString | String | No | - |
| content | String | No | - |
| model | String | No | - |
| prompt | String | No | - |
| confidence | Float | No | 0.0 |
| createdAt | Date | No | - |

**Relationships:**
- recording: To-one → RecordingEntity (Delete Rule: Nullify)
- document: To-one → DocumentEntity (Delete Rule: Nullify)
- keyPoints: To-many → KeyPointEntity (Delete Rule: Cascade)

**Indexes:**
- sourceId (for finding summaries by source)
- summaryTypeString (for filtering by type)

### KeyPointEntity

| Attribute | Type | Optional | Default |
|-----------|------|----------|---------|
| id | UUID | No | - |
| title | String | No | - |
| descriptionText | String | No | - |
| importanceString | String | No | "medium" |
| timestamp | Double | No | 0.0 |

**Relationships:**
- summary: To-one → SummaryEntity (Delete Rule: Nullify)

### TagEntity

| Attribute | Type | Optional | Default |
|-----------|------|----------|---------|
| id | UUID | No | - |
| name | String | No | - |
| colorString | String | No | "blue" |
| categoryString | String | No | "general" |
| usageCount | Integer 32 | No | 0 |
| createdAt | Date | No | - |

**Relationships:**
- recordings: To-many → RecordingEntity (Delete Rule: Nullify)
- documents: To-many → DocumentEntity (Delete Rule: Nullify)

**Indexes:**
- name (for text search and uniqueness)
- usageCount (for sorting by popularity)

### DocumentEntity

| Attribute | Type | Optional | Default |
|-----------|------|----------|---------|
| id | UUID | No | - |
| typeString | String | No | - |
| title | String | No | - |
| content | String | No | - |
| originalURLString | String | Yes | nil |
| fileSize | Integer 64 | No | 0 |
| checksum | String | No | - |
| createdAt | Date | No | - |
| updatedAt | Date | No | - |

**Relationships:**
- tags: To-many → TagEntity (Delete Rule: Nullify)
- summaries: To-many → SummaryEntity (Delete Rule: Cascade)
- embeddings: To-many → VectorEmbeddingEntity (Delete Rule: Cascade)

**Indexes:**
- title (for text search)
- typeString (for filtering by type)
- checksum (for duplicate detection)

### VectorEmbeddingEntity

| Attribute | Type | Optional | Default |
|-----------|------|----------|---------|
| id | UUID | No | - |
| sourceTypeString | String | No | - |
| sourceId | UUID | No | - |
| chunkText | String | No | - |
| vectorData | Binary Data | No | - |
| metadataJSON | Binary Data | Yes | nil |
| createdAt | Date | No | - |
| chunkIndex | Integer 32 | No | 0 |
| startOffset | Integer 32 | No | 0 |
| endOffset | Integer 32 | No | 0 |
| source | String | No | - |
| language | String | No | "ja" |
| confidence | Float | No | 1.0 |
| timestamp | Double | No | 0.0 |

**Relationships:**
- recording: To-one → RecordingEntity (Delete Rule: Nullify)
- document: To-one → DocumentEntity (Delete Rule: Nullify)

**Indexes:**
- sourceId (for finding embeddings by source)
- sourceTypeString (for filtering by source type)
- chunkIndex (for ordering chunks)

## Configuration Settings

### General Settings
- **Code Generation**: Manual/None (we use custom classes)
- **Used with CloudKit**: No (Pro version will use Firebase)
- **Light Weight Migration**: Enabled

### Performance Optimization
- **Fetch Batch Size**: 20 (default)
- **Relationship Delete Rules**: As specified above
- **Indexes**: Created on frequently queried attributes

### Migration Strategy
- **Automatic Migration**: Enabled for minor schema changes
- **Manual Migration**: Required for major structural changes
- **Version Control**: Increment model version for each schema change

## Core Data Stack Configuration

```swift
// In CoreDataManager.swift
lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: "DataModel")
    
    container.persistentStoreDescriptions.forEach { description in
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    }
    
    return container
}()
```

## Notes

1. **Transformable Attributes**: Used for complex data types like arrays and dictionaries
2. **Binary Data**: Used for vector embeddings to optimize storage
3. **Denormalization**: Some metadata fields are stored separately for query performance
4. **Relationships**: Carefully designed delete rules to maintain data integrity
5. **Indexes**: Added on frequently queried attributes for performance

To implement this schema:
1. Create a new Core Data model file named `DataModel.xcdatamodeld` in Xcode
2. Add each entity with the specified attributes and relationships
3. Set the delete rules and other configurations as noted
4. Generate NSManagedObject subclasses or use the custom classes provided