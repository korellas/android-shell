/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2025-2026 Kenny Root
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.connectbot.data.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow
import org.connectbot.data.entity.Pubkey

/**
 * Data Access Object for SSH public/private key pairs.
 *
 * Provides both Flow-based reactive queries for UI observation
 * and suspend functions for one-time operations.
 */
@Dao
interface PubkeyDao {
    /**
     * Observe all pubkeys, ordered by nickname.
     * Emits new list whenever pubkeys are added, updated, or deleted.
     */
    @Query("SELECT * FROM pubkeys ORDER BY nickname ASC")
    fun observeAll(): Flow<List<Pubkey>>

    /**
     * Observe a single pubkey by ID.
     * Emits null if pubkey doesn't exist or is deleted.
     */
    @Query("SELECT * FROM pubkeys WHERE id = :pubkeyId")
    fun observeById(pubkeyId: Long): Flow<Pubkey?>

    /**
     * Get a single pubkey by ID.
     */
    @Query("SELECT * FROM pubkeys WHERE id = :pubkeyId")
    suspend fun getById(pubkeyId: Long): Pubkey?

    /**
     * Get a pubkey by nickname.
     */
    @Query("SELECT * FROM pubkeys WHERE nickname = :nickname")
    suspend fun getByNickname(nickname: String): Pubkey?

    /**
     * Get all pubkeys (one-time query).
     */
    @Query("SELECT * FROM pubkeys ORDER BY nickname ASC")
    suspend fun getAll(): List<Pubkey>

    /**
     * Insert a new pubkey.
     * @return The ID of the newly inserted pubkey
     */
    @Insert
    suspend fun insert(pubkey: Pubkey): Long

    /**
     * Update an existing pubkey.
     */
    @Update
    suspend fun update(pubkey: Pubkey)

    /**
     * Delete a pubkey.
     */
    @Delete
    suspend fun delete(pubkey: Pubkey)
}
