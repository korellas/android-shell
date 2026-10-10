/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
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
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow
import org.connectbot.data.entity.Identity

@Dao
interface IdentityDao {
    @Query("SELECT * FROM identities ORDER BY name")
    fun observeAll(): Flow<List<Identity>>

    @Query("SELECT * FROM identities ORDER BY name")
    suspend fun getAll(): List<Identity>

    @Query("SELECT * FROM identities WHERE id = :id")
    suspend fun getById(id: Long): Identity?

    @Insert
    suspend fun insert(identity: Identity): Long

    @Update
    suspend fun update(identity: Identity)

    @Query("DELETE FROM identities WHERE id = :id")
    suspend fun delete(id: Long)
}
