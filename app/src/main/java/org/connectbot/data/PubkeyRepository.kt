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

package org.connectbot.data

import kotlinx.coroutines.flow.Flow
import org.connectbot.data.dao.PubkeyDao
import org.connectbot.data.entity.Pubkey
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository for managing SSH public/private key pairs.
 * Handles pubkey CRUD operations.
 *
 * @param pubkeyDao The DAO for accessing pubkey data
 */
@Singleton
class PubkeyRepository @Inject constructor(
    private val pubkeyDao: PubkeyDao,
) {

    // ============================================================================
    // Pubkey Operations
    // ============================================================================

    /**
     * Observe all pubkeys reactively.
     *
     * @return Flow of pubkey list that updates automatically
     */
    fun observeAll(): Flow<List<Pubkey>> = pubkeyDao.observeAll()

    /**
     * Observe a specific pubkey reactively.
     *
     * @param pubkeyId The pubkey ID
     * @return Flow of pubkey that updates automatically
     */
    fun observePubkey(pubkeyId: Long): Flow<Pubkey?> = pubkeyDao.observeById(pubkeyId)

    /**
     * Get all pubkeys.
     *
     * @return List of all pubkeys
     */
    suspend fun getAll(): List<Pubkey> = pubkeyDao.getAll()

    /**
     * Find a pubkey by its unique ID.
     *
     * @param pubkeyId The pubkey ID
     * @return The pubkey, or null if not found
     */
    suspend fun getById(pubkeyId: Long): Pubkey? = pubkeyDao.getById(pubkeyId)

    /**
     * Find a pubkey by nickname.
     *
     * @param nickname The pubkey nickname
     * @return The pubkey, or null if not found
     */
    suspend fun getByNickname(nickname: String): Pubkey? = pubkeyDao.getByNickname(nickname)

    /**
     * Save a pubkey (insert or update).
     *
     * @param pubkey The pubkey to save
     * @return The saved pubkey with updated ID
     */
    suspend fun save(pubkey: Pubkey): Pubkey = if (pubkey.id == 0L) {
        // New pubkey - insert
        val newId = pubkeyDao.insert(pubkey)
        pubkey.copy(id = newId)
    } else {
        // Existing pubkey - update
        pubkeyDao.update(pubkey)
        pubkey
    }

    /**
     * Delete a pubkey.
     *
     * @param pubkey The pubkey to delete
     */
    suspend fun delete(pubkey: Pubkey) {
        pubkeyDao.delete(pubkey)
    }
}
