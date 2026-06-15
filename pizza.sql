-- ============================================
-- JOB PIZZA PREMIUM 2026 - ESX LEGACY
-- Sans whitelisted
-- Optimisé oxmysql
-- Système société intégré
-- ============================================

-- ============================================
-- 1. JOB
-- ============================================

INSERT INTO `jobs` (`name`, `label`) VALUES
('pizza', 'Pizza Delivery')
ON DUPLICATE KEY UPDATE
`label` = VALUES(`label`);

-- ============================================
-- 2. GRADES DU JOB
-- ============================================

INSERT INTO `job_grades`
(`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`)
VALUES

('pizza', 0, 'recrue', 'Livreur', 50, '{}', '{}'),

('pizza', 1, 'livreur', 'Livreur Confirmé', 75, '{}', '{}'),

('pizza', 2, 'chef', 'Chef d''équipe', 100, '{}', '{}'),

('pizza', 3, 'boss', 'Patron', 150, '{}', '{}')

ON DUPLICATE KEY UPDATE
`label` = VALUES(`label`),
`salary` = VALUES(`salary`);

-- ============================================
-- 3. TABLE STATISTIQUES LIVRAISON
-- ============================================

CREATE TABLE IF NOT EXISTS `pizza_delivery` (

    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,

    `deliveries` INT NOT NULL DEFAULT 0,
    `earnings` INT NOT NULL DEFAULT 0,
    `xp` INT NOT NULL DEFAULT 0,
    `level` INT NOT NULL DEFAULT 1,

    `last_delivery` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_identifier` (`identifier`),
    KEY `idx_deliveries` (`deliveries`),
    KEY `idx_earnings` (`earnings`),
    KEY `idx_xp` (`xp`),
    KEY `idx_level` (`level`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- 4. TABLE SOCIÉTÉ
-- ============================================

CREATE TABLE IF NOT EXISTS `pizza_society` (

    `id` INT NOT NULL AUTO_INCREMENT,
    `balance` INT NOT NULL DEFAULT 50000,

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Initialiser le solde société
INSERT INTO `pizza_society` (`balance`) VALUES (50000)
WHERE NOT EXISTS (SELECT 1 FROM `pizza_society`);

-- ============================================
-- 5. TABLE LOGS SOCIÉTÉ
-- ============================================

CREATE TABLE IF NOT EXISTS `pizza_society_logs` (

    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `action` VARCHAR(50) NOT NULL,
    `amount` INT NOT NULL,
    `description` VARCHAR(255),
    `date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    KEY `idx_identifier` (`identifier`),
    KEY `idx_action` (`action`),
    KEY `idx_date` (`date`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- 6. TABLE VÉHICULES JOB
-- ============================================

CREATE TABLE IF NOT EXISTS `pizza_vehicles` (

    `id` INT NOT NULL AUTO_INCREMENT,
    `plate` VARCHAR(12) NOT NULL,

    `vehicle` VARCHAR(50) NOT NULL,
    `identifier` VARCHAR(60),

    `state` TINYINT NOT NULL DEFAULT 1,

    `stored_at` TIMESTAMP NULL DEFAULT NULL,
    `taken_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),

    UNIQUE KEY `uniq_plate` (`plate`),

    KEY `idx_identifier` (`identifier`),
    KEY `idx_vehicle` (`vehicle`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- 7. TABLE COMMANDES
-- ============================================

CREATE TABLE IF NOT EXISTS `pizza_orders` (

    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `client_name` VARCHAR(100),
    `address` VARCHAR(255),
    `coords_x` FLOAT,
    `coords_y` FLOAT,
    `coords_z` FLOAT,
    `reward` INT,
    `status` VARCHAR(20) DEFAULT 'pending',
    `accepted_at` TIMESTAMP NULL,
    `completed_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    KEY `idx_identifier` (`identifier`),
    KEY `idx_status` (`status`),
    KEY `idx_created_at` (`created_at`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- 8. VÉRIFICATION
-- ============================================

SELECT 'JOB PIZZA PREMIUM OK' AS status;

SELECT COUNT(*) AS total_grades
FROM `job_grades`
WHERE `job_name` = 'pizza';

SELECT COUNT(*) AS society_count
FROM `pizza_society`;