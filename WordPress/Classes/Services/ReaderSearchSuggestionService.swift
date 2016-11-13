import Foundation

/// Provides functionality for fetching, saving, and deleting search phrases
/// used to search for content in the reader.
///
@objc class ReaderSearchSuggestionService : LocalCoreDataService
{

    /// Creates or updates an existing record for the specified search phrase.
    ///
    /// - Parameters:
    ///     - phrase: The search phrase in question.
    ///
    func createOrUpdateSuggestionForPhrase(phrase: String) {
        var suggestion = findSuggestionForPhrase(phrase)
        if suggestion == nil {
            suggestion = NSEntityDescription.insertNewObjectForEntityForName(ReaderSearchSuggestion.classNameWithoutNamespaces(),
                                                                             inManagedObjectContext: managedObjectContext) as? ReaderSearchSuggestion
            suggestion?.searchPhrase = phrase
        }
        suggestion?.date = NSDate()
        ContextManager.sharedInstance().saveContext(managedObjectContext)
    }


    /// Find and return the ReaderSearchSuggestion matching the specified search phrase.
    ///
    /// - Parameters:
    ///     - phrase: The search phrase in question.
    ///
    /// - Returns: A matching search phrase or nil.
    ///
    func findSuggestionForPhrase(phrase: String) -> ReaderSearchSuggestion? {
        let fetchRequest = NSFetchRequest(entityName: "ReaderSearchSuggestion")
        fetchRequest.predicate = NSPredicate(format: "searchPhrase MATCHES[cd] %@", phrase)

        var suggestions = [ReaderSearchSuggestion]()
        do {
            suggestions = try managedObjectContext.executeFetchRequest(fetchRequest) as! [ReaderSearchSuggestion]
        } catch let error as NSError {
            DDLogSwift.logError("Error fetching search suggestion for phrase \(phrase) : \(error.localizedDescription)")
        }

        return suggestions.first
    }


    /// Finds and returns all ReaderSearchSuggestion starting with the specified search phrase.
    ///
    /// - Parameters:
    ///     - phrase: The search phrase in question.
    ///
    /// - Returns: An array of matching `ReaderSearchSuggestion`s.
    ///
    func fetchSuggestionsLikePhrase(phrase: String) -> [ReaderSearchSuggestion] {
        let fetchRequest = NSFetchRequest(entityName: "ReaderSearchSuggestion")
        fetchRequest.predicate = NSPredicate(format: "searchPhrase BEGINSWITH[cd] %@", phrase)

        let sort = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sort]

        var suggestions = [ReaderSearchSuggestion]()
        do {
            suggestions = try managedObjectContext.executeFetchRequest(fetchRequest) as! [ReaderSearchSuggestion]
        } catch let error as NSError {
            DDLogSwift.logError("Error fetching search suggestions for phrase \(phrase) : \(error.localizedDescription)")
        }

        return suggestions
    }


    /// Deletes the specified search suggestion.
    ///
    /// - Parameters:
    ///     - suggestion: The `ReaderSearchSuggestion` to delete.
    ///
    func deleteSuggestion(suggestion: ReaderSearchSuggestion) {
        managedObjectContext.deleteObject(suggestion)
        ContextManager.sharedInstance().saveContextAndWait(managedObjectContext)
    }


    /// Deletes all saved search suggestions.
    ///
    func deleteAllSuggestions() {
        let fetchRequest = NSFetchRequest(entityName: "ReaderSearchSuggestion")
        var suggestions = [ReaderSearchSuggestion]()
        do {
            suggestions = try managedObjectContext.executeFetchRequest(fetchRequest) as! [ReaderSearchSuggestion]
        } catch let error as NSError {
            DDLogSwift.logError("Error fetching search suggestion : \(error.localizedDescription)")
        }
        for suggestion in suggestions {
            managedObjectContext.deleteObject(suggestion)
        }
        ContextManager.sharedInstance().saveContext(managedObjectContext)
    }

}
