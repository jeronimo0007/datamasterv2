package com.fraud.local.mongo;

import java.util.Optional;
import org.springframework.context.annotation.Profile;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

@Repository
@Profile("local")
public interface UserProfileRepository extends MongoRepository<UserProfileDocument, String> {

    Optional<UserProfileDocument> findByUserId(String userId);

    long count();
}
