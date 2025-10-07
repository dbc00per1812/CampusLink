//
//  MockSupabaseClient.swift
//  CampusLinkTests
//
//  Created on October 7, 2025.
//

import Foundation
@testable import CampusLink
import Supabase

// MARK: - Mock Types

struct MockError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Mock Supabase Response

struct MockSupabaseResponse<T> {
    let value: T
}

// MARK: - Mock Query Builder

class MockQueryBuilder<T: Decodable> {
    var tableName: String
    var filters: [(String, Any)] = []
    var limit: Int?
    var orderBy: String?
    var ascending: Bool = true
    var response: T?
    var error: Error?
    
    init(tableName: String) {
        self.tableName = tableName
    }
    
    func select() -> Self {
        return self
    }
    
    func eq(_ column: String, value: Any) -> Self {
        filters.append((column, value))
        return self
    }
    
    func neq(_ column: String, value: Any) -> Self {
        filters.append(("!\(column)", value))
        return self
    }
    
    func or(_ query: String) -> Self {
        filters.append(("or", query))
        return self
    }
    
    func limit(_ count: Int) -> Self {
        self.limit = count
        return self
    }
    
    func order(_ column: String, ascending: Bool = true) -> Self {
        self.orderBy = column
        self.ascending = ascending
        return self
    }
    
    func execute() async throws -> MockSupabaseResponse<T> {
        if let error = error {
            throw error
        }
        guard let response = response else {
            throw MockError(message: "No mock response configured")
        }
        return MockSupabaseResponse(value: response)
    }
}

// MARK: - Mock RPC Builder

class MockRPCBuilder<T: Decodable> {
    var functionName: String
    var params: [String: Any]?
    var response: T?
    var error: Error?
    
    init(functionName: String, params: [String: Any]?) {
        self.functionName = functionName
        self.params = params
    }
    
    func execute() async throws -> MockSupabaseResponse<T> {
        if let error = error {
            throw error
        }
        guard let response = response else {
            throw MockError(message: "No mock response configured")
        }
        return MockSupabaseResponse(value: response)
    }
}

// MARK: - Mock Auth

class MockSupabaseAuth {
    var session: Session?
    var error: Error?
    
    var sessionAsync: Session {
        get async throws {
            if let error = error {
                throw error
            }
            guard let session = session else {
                throw MockError(message: "No session available")
            }
            return session
        }
    }
}

// MARK: - Mock Functions

class MockSupabaseFunctions {
    var responses: [String: Any] = [:]
    var errors: [String: Error] = [:]
    
    func invoke<T: Decodable>(_ functionName: String, options: FunctionInvokeOptions? = nil) async throws -> T {
        if let error = errors[functionName] {
            throw error
        }
        guard let response = responses[functionName] as? T else {
            throw MockError(message: "No mock response for function: \(functionName)")
        }
        return response
    }
}

// MARK: - Mock Database Client

class MockSupabaseDatabase {
    var tables: [String: [Any]] = [:]
    var errors: [String: Error] = [:]
    
    func from<T: Decodable>(_ table: String) -> MockQueryBuilder<T> {
        let builder = MockQueryBuilder<T>(tableName: table)
        
        // Configure response based on table data
        if let tableData = tables[table] as? T {
            builder.response = tableData
        }
        
        // Configure error if set
        if let error = errors[table] {
            builder.error = error
        }
        
        return builder
    }
    
    func rpc<T: Decodable>(_ functionName: String, params: [String: Any]? = nil) -> MockRPCBuilder<T> {
        let builder = MockRPCBuilder<T>(functionName: functionName, params: params)
        
        // Configure response based on function data
        if let functionData = tables["rpc_\(functionName)"] as? T {
            builder.response = functionData
        }
        
        // Configure error if set
        if let error = errors["rpc_\(functionName)"] {
            builder.error = error
        }
        
        return builder
    }
}

// MARK: - Mock Session & User

extension Session {
    static func mockSession(userId: UUID = UUID()) -> Session {
        let user = User(
            id: userId,
            appMetadata: [:],
            userMetadata: [:],
            aud: "authenticated",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        return Session(
            accessToken: "mock-access-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            refreshToken: "mock-refresh-token",
            user: user
        )
    }
}

// MARK: - Test Helpers

class MockSupabaseClient {
    let auth = MockSupabaseAuth()
    let functions = MockSupabaseFunctions()
    let database = MockSupabaseDatabase()
    
    // Helper methods for test setup
    func setAuthSession(_ session: Session?) {
        auth.session = session
    }
    
    func setAuthError(_ error: Error) {
        auth.error = error
    }
    
    func setTableData<T>(_ table: String, data: T) {
        database.tables[table] = data
    }
    
    func setTableError(_ table: String, error: Error) {
        database.errors[table] = error
    }
    
    func setFunctionResponse(_ functionName: String, response: Any) {
        functions.responses[functionName] = response
    }
    
    func setFunctionError(_ functionName: String, error: Error) {
        functions.errors[functionName] = error
    }
    
    func setRPCResponse<T>(_ functionName: String, response: T) {
        database.tables["rpc_\(functionName)"] = response
    }
    
    func setRPCError(_ functionName: String, error: Error) {
        database.errors["rpc_\(functionName)"] = error
    }
}
