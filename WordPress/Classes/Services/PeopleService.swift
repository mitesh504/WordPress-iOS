import Foundation


/// Service providing access to the People Management WordPress.com API.
///
struct PeopleService {
    /// MARK: - Public Properties
    ///
    let siteID: Int

    /// MARK: - Private Properties
    ///
    private let context: NSManagedObjectContext
    private let remote: PeopleRemote


    /// Designated Initializer.
    ///
    /// - Parameters:
    ///     - blog: Target Blog Instance
    ///     - context: CoreData context to be used.
    ///
    init?(blog: Blog, context: NSManagedObjectContext) {
        guard let api = blog.wordPressComRestApi(), dotComID = blog.dotComID as? Int else {
            return nil
        }

        self.remote = PeopleRemote(wordPressComRestApi: api)
        self.siteID = dotComID
        self.context = context
    }

    /// Loads a page of Users associated to the current blog, starting at the specified offset.
    ///
    /// - Parameters:
    ///     - offset: Number of records to skip.
    ///     - count: Number of records to retrieve. By default set to 20.
    ///     - success: Closure to be executed on success.
    ///     - failure: Closure to be executed on failure.
    ///
    func loadUsersPage(offset: Int = 0, count: Int = 20, success: ((retrieved: Int, shouldLoadMore: Bool) -> Void), failure: (ErrorType -> Void)? = nil) {
        remote.getUsers(siteID, offset: offset, count: count, success: { users, hasMore in
            self.mergePeople(users)
            success(retrieved: users.count, shouldLoadMore: hasMore)

        }, failure: { error in
            DDLogSwift.logError(String(error))
            failure?(error)
        })
    }

    /// Loads a page of Followers associated to the current blog, starting at the specified offset.
    ///
    /// - Parameters:
    ///     - offset: Number of records to skip.
    ///     - count: Number of records to retrieve. By default set to 20.
    ///     - success: Closure to be executed on success.
    ///     - failure: Closure to be executed on failure.
    ///
    func loadFollowersPage(offset: Int = 0, count: Int = 20, success: ((retrieved: Int, shouldLoadMore: Bool) -> Void), failure: (ErrorType -> Void)? = nil) {
        remote.getFollowers(siteID, offset: offset, count: count, success: { followers, hasMore in
            self.mergePeople(followers)
            success(retrieved: followers.count, shouldLoadMore: hasMore)

        }, failure: { error in
            DDLogSwift.logError(String(error))
            failure?(error)
        })
    }

    /// Loads a page of Viewers associated to the current blog, starting at the specified offset.
    ///
    /// - Parameters:
    ///     - offset: Number of records to skip.
    ///     - count: Number of records to retrieve. By default set to 20.
    ///     - success: Closure to be executed on success.
    ///     - failure: Closure to be executed on failure.
    ///
    func loadViewersPage(offset: Int = 0, count: Int = 20, success: ((retrieved: Int, shouldLoadMore: Bool) -> Void), failure: (ErrorType -> Void)? = nil) {
        remote.getViewers(siteID, offset: offset, count: count, success: { viewers, hasMore in
            self.mergePeople(viewers)
            success(retrieved: viewers.count, shouldLoadMore: hasMore)

        }, failure: { error in
            DDLogSwift.logError(String(error))
            failure?(error)
        })
    }

    /// Updates a given User with the specified role.
    ///
    /// - Parameters:
    ///     - user: Instance of the person to be updated.
    ///     - role: New role that should be assigned
    ///     - failure: Optional closure, to be executed in case of error
    ///
    /// - Returns: A new Person instance, with the new Role already assigned.
    ///
    func updateUser(user: User, role: Role, failure: ((ErrorType, User) -> Void)?) -> User {
        guard let managedPerson = managedPersonFromPerson(user) else {
            return user
        }

        // OP Reversal
        let pristineRole = managedPerson.role

        // Hit the Backend
        remote.updateUserRole(siteID, userID: user.ID, newRole: role, success: nil, failure: { error in

            DDLogSwift.logError("### Error while updating person \(user.ID) in blog \(self.siteID): \(error)")

            guard let managedPerson = self.managedPersonFromPerson(user) else {
                DDLogSwift.logError("### Person with ID \(user.ID) deleted before update")
                return
            }

            managedPerson.role = pristineRole

            let reloadedPerson = User(managedPerson: managedPerson)
            failure?(error, reloadedPerson)
        })

        // Pre-emptively update the role
        managedPerson.role = role.description

        return User(managedPerson: managedPerson)
    }

    /// Deletes a given User.
    ///
    /// - Parameters:
    ///     - user: The person that should be deleted
    ///     - failure: Closure to be executed on error
    ///
    func deleteUser(user: User, failure: (ErrorType -> Void)? = nil) {
        guard let managedPerson = managedPersonFromPerson(user) else {
            return
        }

        // Hit the Backend
        remote.deleteUser(siteID, userID: user.ID, failure: { error in

            DDLogSwift.logError("### Error while deleting person \(user.ID) from blog \(self.siteID): \(error)")

            // Revert the deletion
            self.createManagedPerson(user)

            failure?(error)
        })

        // Pre-emptively nuke the entity
        context.deleteObject(managedPerson)
    }

    /// Retrieves the collection of Roles, available for a given site
    ///
    /// - Parameters:
    ///     - success: Closure to be executed in case of success. The collection of Roles will be passed on.
    ///     - failure: Closure to be executed in case of error
    ///
    func loadAvailableRoles(success: ([Role] -> Void), failure: (ErrorType -> Void)) {
        remote.getUserRoles(siteID, success: { roles in
            success(roles)

        }, failure: { error in
            failure(error)
        })
    }

    /// Validates Invitation Recipients.
    ///
    /// - Parameters:
    ///     - usernameOrEmail: Recipient that should be validated.
    ///     - role: Role that would be granted to the recipient.
    ///     - success: Closure to be executed on success
    ///     - failure: Closure to be executed on error.
    ///
    func validateInvitation(usernameOrEmail: String,
                            role: Role,
                            success: (Void -> Void),
                            failure: (ErrorType -> Void))
    {
        remote.validateInvitation(siteID,
                                  usernameOrEmail: usernameOrEmail,
                                  role: role,
                                  success: success,
                                  failure: failure)
    }


    /// Sends an Invitation to a specified recipient, to access a Blog.
    ///
    /// - Parameters:
    ///     - usernameOrEmail: Recipient that should be validated.
    ///     - role: Role that would be granted to the recipient.
    ///     - message: String that should be sent to the users.
    ///     - success: Closure to be executed on success
    ///     - failure: Closure to be executed on error.
    ///
    func sendInvitation(usernameOrEmail: String,
                        role: Role,
                        message: String = "",
                        success: (Void -> Void),
                        failure: (ErrorType -> Void))
    {
        remote.sendInvitation(siteID,
                              usernameOrEmail: usernameOrEmail,
                              role: role,
                              message: message,
                              success: success,
                              failure: failure)
    }
}


/// Encapsulates all of the PeopleService Private Methods.
///
private extension PeopleService {
    /// Updates the Core Data collection of users, to match with the array of People received.
    ///
    func mergePeople<T : Person>(remotePeople: [T]) {
        for remotePerson in remotePeople {
            if let existingPerson = managedPersonFromPerson(remotePerson) {
                existingPerson.updateWith(remotePerson)
                DDLogSwift.logDebug("Updated person \(existingPerson)")
            } else {
                createManagedPerson(remotePerson)
            }
        }
    }

    /// Retrieves the collection of users, persisted in Core Data, associated with the current blog.
    ///
    func loadPeople<T : Person>(siteID: Int, type: T.Type) -> [T] {
        let request = NSFetchRequest(entityName: "Person")
        request.predicate = NSPredicate(format: "siteID = %@ AND kind = %@",
                                        NSNumber(integer: siteID),
                                        NSNumber(integer: type.kind.rawValue))
        let results: [ManagedPerson]
        do {
            results = try context.executeFetchRequest(request) as! [ManagedPerson]
        } catch {
            DDLogSwift.logError("Error fetching all people: \(error)")
            results = []
        }

        return results.map { return T(managedPerson: $0) }
    }

    /// Retrieves a Person from Core Data, with the specifiedID.
    ///
    func managedPersonFromPerson(person: Person) -> ManagedPerson? {
        let request = NSFetchRequest(entityName: "Person")
        request.predicate = NSPredicate(format: "siteID = %@ AND userID = %@ AND kind = %@",
                                                NSNumber(integer: siteID),
                                                NSNumber(integer: person.ID),
                                                NSNumber(integer: person.dynamicType.kind.rawValue))
        request.fetchLimit = 1

        let results = (try? context.executeFetchRequest(request) as! [ManagedPerson]) ?? []
        return results.first
    }

    /// Nukes the set of users, from Core Data, with the specified ID's.
    ///
    func removeManagedPeopleWithIDs<T : Person>(ids: Set<Int>, type: T.Type) {
        if ids.isEmpty {
            return
        }

        let numberIDs = ids.map { return NSNumber(integer: $0) }
        let request = NSFetchRequest(entityName: "Person")
        request.predicate = NSPredicate(format: "siteID = %@ AND kind = %@ AND userID IN %@",
                                        NSNumber(integer: siteID),
                                        NSNumber(integer: type.kind.rawValue),
                                        numberIDs)

        let objects = (try? context.executeFetchRequest(request) as! [NSManagedObject]) ?? []
        for object in objects {
            DDLogSwift.logDebug("Removing person: \(object)")
            context.deleteObject(object)
        }
    }

    /// Inserts a new Person instance into Core Data, with the specified payload.
    ///
    func createManagedPerson<T: Person>(person: T) {
        let managedPerson = NSEntityDescription.insertNewObjectForEntityForName("Person", inManagedObjectContext: context) as! ManagedPerson
        managedPerson.updateWith(person)
        managedPerson.creationDate = NSDate()
        DDLogSwift.logDebug("Created person \(managedPerson)")
    }
}
