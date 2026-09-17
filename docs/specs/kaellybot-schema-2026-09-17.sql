-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Hôte : mysql:3306
-- Généré le : jeu. 17 sep. 2026 à 10:59
-- Version du serveur : 8.4.3
-- Version de PHP : 8.2.25

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de données : `kaellybot`
--

-- --------------------------------------------------------

--
-- Structure de la table `alignment_books`
--

CREATE TABLE `alignment_books` (
  `user_id` varchar(100) NOT NULL,
  `city_id` varchar(100) NOT NULL,
  `order_id` varchar(100) NOT NULL,
  `server_id` varchar(100) NOT NULL,
  `game` int NOT NULL,
  `level` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `almanaxes`
--

CREATE TABLE `almanaxes` (
  `month` int NOT NULL,
  `day` int NOT NULL,
  `dofus_dude_effect_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `almanax_news`
--

CREATE TABLE `almanax_news` (
  `locale` int NOT NULL,
  `game` int NOT NULL,
  `news_channel_id` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `channel_servers`
--

CREATE TABLE `channel_servers` (
  `guild_id` varchar(100) NOT NULL,
  `channel_id` varchar(100) NOT NULL,
  `game` int NOT NULL,
  `server_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `characteristics`
--

CREATE TABLE `characteristics` (
  `id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `debug_name` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `emoji_type` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `sort_order` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `cities`
--

CREATE TABLE `cities` (
  `id` varchar(191) NOT NULL,
  `icon` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `emoji_type` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `color` int NOT NULL,
  `type` varchar(100) NOT NULL,
  `game` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `city_labels`
--

CREATE TABLE `city_labels` (
  `city_id` varchar(191) NOT NULL,
  `game` int NOT NULL DEFAULT '1',
  `locale` int NOT NULL,
  `label` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `emojis`
--

CREATE TABLE `emojis` (
  `id` varchar(191) NOT NULL,
  `type` varchar(191) NOT NULL,
  `snowflake_dev` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `snowflake` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `discord_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `debug_name` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `equipment_types`
--

CREATE TABLE `equipment_types` (
  `equipment_id` int NOT NULL,
  `item_id` int NOT NULL,
  `dofus_dude_id` int NOT NULL,
  `debug_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `equipment_type_weapon_area_effects`
--

CREATE TABLE `equipment_type_weapon_area_effects` (
  `equipment_id` int NOT NULL,
  `item_id` int NOT NULL,
  `dofus_dude_id` int NOT NULL,
  `weapon_area_effect_id` varchar(191) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `feed_sources`
--

CREATE TABLE `feed_sources` (
  `feed_type_id` varchar(191) NOT NULL,
  `news_channel_id` varchar(100) NOT NULL,
  `url` varchar(191) NOT NULL,
  `game` int NOT NULL,
  `locale` int NOT NULL,
  `last_update` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `feed_types`
--

CREATE TABLE `feed_types` (
  `id` varchar(191) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `feed_type_labels`
--

CREATE TABLE `feed_type_labels` (
  `locale` int NOT NULL,
  `feed_type_id` varchar(191) NOT NULL,
  `label` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `game_versions`
--

CREATE TABLE `game_versions` (
  `id` int NOT NULL,
  `version` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `guilds`
--

CREATE TABLE `guilds` (
  `id` varchar(100) NOT NULL,
  `game` int NOT NULL,
  `server_id` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `jobs`
--

CREATE TABLE `jobs` (
  `id` varchar(100) NOT NULL,
  `icon` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `color` int NOT NULL,
  `emoji_type` varchar(191) NOT NULL,
  `game` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `job_books`
--

CREATE TABLE `job_books` (
  `user_id` varchar(100) NOT NULL,
  `job_id` varchar(100) NOT NULL,
  `server_id` varchar(100) NOT NULL,
  `game` int NOT NULL,
  `level` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `job_labels`
--

CREATE TABLE `job_labels` (
  `job_id` varchar(191) NOT NULL,
  `game` int NOT NULL,
  `locale` int NOT NULL,
  `label` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `orders`
--

CREATE TABLE `orders` (
  `id` varchar(191) NOT NULL,
  `game` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `order_labels`
--

CREATE TABLE `order_labels` (
  `order_id` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `game` int NOT NULL,
  `locale` int NOT NULL,
  `label` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `regex_characteristics`
--

CREATE TABLE `regex_characteristics` (
  `characteristic_id` varchar(191) NOT NULL,
  `debug_name` varchar(30) NOT NULL,
  `expression` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `relative_characteristic_id` varchar(191) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `servers`
--

CREATE TABLE `servers` (
  `id` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `dofus_portals_id` varchar(191) DEFAULT NULL,
  `game` int NOT NULL,
  `icon` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `image` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `emoji_type` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `server_labels`
--

CREATE TABLE `server_labels` (
  `locale` int NOT NULL,
  `server_id` varchar(191) NOT NULL,
  `label` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `sets`
--

CREATE TABLE `sets` (
  `id` int NOT NULL,
  `game` int NOT NULL,
  `hash` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `icon` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `is_current` tinyint(1) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `twitter_accounts`
--

CREATE TABLE `twitter_accounts` (
  `id` varchar(191) NOT NULL,
  `name` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `news_channel_id` varchar(100) NOT NULL,
  `locale` int NOT NULL,
  `game` int NOT NULL,
  `last_update` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `weapon_area_effects`
--

CREATE TABLE `weapon_area_effects` (
  `id` varchar(191) NOT NULL,
  `type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `emoji_type` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `order` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `weapon_area_effect_labels`
--

CREATE TABLE `weapon_area_effect_labels` (
  `weapon_area_effect_id` varchar(191) NOT NULL,
  `locale` int NOT NULL,
  `label` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `weapon_exceptions`
--

CREATE TABLE `weapon_exceptions` (
  `dofus_dude_id` int NOT NULL,
  `weapon_area_effect_id` varchar(191) NOT NULL,
  `debug_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `webhook_almanaxes`
--

CREATE TABLE `webhook_almanaxes` (
  `webhook_id` varchar(191) NOT NULL,
  `guild_id` varchar(191) NOT NULL,
  `channel_id` varchar(191) NOT NULL,
  `game` int NOT NULL,
  `locale` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `webhook_feeds`
--

CREATE TABLE `webhook_feeds` (
  `webhook_id` varchar(191) NOT NULL,
  `guild_id` varchar(191) NOT NULL,
  `channel_id` varchar(191) NOT NULL,
  `feed_type_id` varchar(191) NOT NULL,
  `game` int NOT NULL,
  `locale` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `webhook_twitters`
--

CREATE TABLE `webhook_twitters` (
  `webhook_id` varchar(191) NOT NULL,
  `guild_id` varchar(191) NOT NULL,
  `channel_id` varchar(191) NOT NULL,
  `twitter_id` varchar(191) NOT NULL,
  `game` int NOT NULL,
  `locale` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Index pour les tables déchargées
--

--
-- Index pour la table `alignment_books`
--
ALTER TABLE `alignment_books`
  ADD PRIMARY KEY (`user_id`,`city_id`,`order_id`,`server_id`,`game`) USING BTREE,
  ADD KEY `fk_alignment_books_server` (`server_id`),
  ADD KEY `fk_alignment_books_city` (`city_id`,`game`) USING BTREE,
  ADD KEY `fk_alignment_books_order` (`order_id`,`game`) USING BTREE;

--
-- Index pour la table `almanaxes`
--
ALTER TABLE `almanaxes`
  ADD PRIMARY KEY (`month`,`day`);

--
-- Index pour la table `almanax_news`
--
ALTER TABLE `almanax_news`
  ADD PRIMARY KEY (`locale`,`game`);

--
-- Index pour la table `channel_servers`
--
ALTER TABLE `channel_servers`
  ADD PRIMARY KEY (`guild_id`,`channel_id`,`game`) USING BTREE,
  ADD KEY `fk_channel_servers_server` (`server_id`),
  ADD KEY `fk_channel_servers_guild` (`guild_id`,`game`);

--
-- Index pour la table `characteristics`
--
ALTER TABLE `characteristics`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `sort_order` (`sort_order`),
  ADD KEY `fk_characteristic_emoji` (`id`,`emoji_type`);

--
-- Index pour la table `cities`
--
ALTER TABLE `cities`
  ADD PRIMARY KEY (`id`,`game`) USING BTREE,
  ADD KEY `fk_city_emoji` (`id`,`emoji_type`);

--
-- Index pour la table `city_labels`
--
ALTER TABLE `city_labels`
  ADD PRIMARY KEY (`city_id`,`game`,`locale`) USING BTREE;

--
-- Index pour la table `emojis`
--
ALTER TABLE `emojis`
  ADD PRIMARY KEY (`id`,`type`);

--
-- Index pour la table `equipment_types`
--
ALTER TABLE `equipment_types`
  ADD PRIMARY KEY (`equipment_id`,`item_id`,`dofus_dude_id`) USING BTREE;

--
-- Index pour la table `equipment_type_weapon_area_effects`
--
ALTER TABLE `equipment_type_weapon_area_effects`
  ADD PRIMARY KEY (`equipment_id`,`item_id`,`dofus_dude_id`,`weapon_area_effect_id`),
  ADD KEY `fk_equipment_type_weapon_area_effects_weapon_area_effect` (`weapon_area_effect_id`);

--
-- Index pour la table `feed_sources`
--
ALTER TABLE `feed_sources`
  ADD PRIMARY KEY (`feed_type_id`,`game`,`locale`) USING BTREE;

--
-- Index pour la table `feed_types`
--
ALTER TABLE `feed_types`
  ADD PRIMARY KEY (`id`);

--
-- Index pour la table `feed_type_labels`
--
ALTER TABLE `feed_type_labels`
  ADD PRIMARY KEY (`locale`,`feed_type_id`),
  ADD KEY `fk_feed_types_labels` (`feed_type_id`);

--
-- Index pour la table `game_versions`
--
ALTER TABLE `game_versions`
  ADD PRIMARY KEY (`id`);

--
-- Index pour la table `guilds`
--
ALTER TABLE `guilds`
  ADD PRIMARY KEY (`id`,`game`) USING BTREE,
  ADD KEY `fk_guilds_server` (`server_id`);

--
-- Index pour la table `jobs`
--
ALTER TABLE `jobs`
  ADD PRIMARY KEY (`id`,`game`) USING BTREE,
  ADD KEY `fk_job_emoji` (`id`,`emoji_type`);

--
-- Index pour la table `job_books`
--
ALTER TABLE `job_books`
  ADD PRIMARY KEY (`user_id`,`job_id`,`server_id`,`game`) USING BTREE,
  ADD KEY `fk_job_books_job` (`job_id`,`game`) USING BTREE,
  ADD KEY `fk_job_books_server` (`server_id`) USING BTREE;

--
-- Index pour la table `job_labels`
--
ALTER TABLE `job_labels`
  ADD PRIMARY KEY (`job_id`,`game`,`locale`) USING BTREE;

--
-- Index pour la table `orders`
--
ALTER TABLE `orders`
  ADD PRIMARY KEY (`id`,`game`) USING BTREE;

--
-- Index pour la table `order_labels`
--
ALTER TABLE `order_labels`
  ADD PRIMARY KEY (`order_id`,`game`,`locale`) USING BTREE;

--
-- Index pour la table `regex_characteristics`
--
ALTER TABLE `regex_characteristics`
  ADD PRIMARY KEY (`characteristic_id`,`expression`) USING BTREE,
  ADD KEY `fk_regex_relative_characteristic_id` (`relative_characteristic_id`);

--
-- Index pour la table `servers`
--
ALTER TABLE `servers`
  ADD PRIMARY KEY (`id`) USING BTREE,
  ADD UNIQUE KEY `dofus_portals_id` (`dofus_portals_id`),
  ADD KEY `fk_server_emoji` (`id`,`emoji_type`);

--
-- Index pour la table `server_labels`
--
ALTER TABLE `server_labels`
  ADD PRIMARY KEY (`locale`,`server_id`),
  ADD KEY `fk_servers_labels` (`server_id`);

--
-- Index pour la table `sets`
--
ALTER TABLE `sets`
  ADD PRIMARY KEY (`id`,`game`);

--
-- Index pour la table `twitter_accounts`
--
ALTER TABLE `twitter_accounts`
  ADD PRIMARY KEY (`id`) USING BTREE,
  ADD KEY `name` (`name`);

--
-- Index pour la table `weapon_area_effects`
--
ALTER TABLE `weapon_area_effects`
  ADD PRIMARY KEY (`id`),
  ADD KEY `id` (`id`,`emoji_type`);

--
-- Index pour la table `weapon_area_effect_labels`
--
ALTER TABLE `weapon_area_effect_labels`
  ADD PRIMARY KEY (`weapon_area_effect_id`,`locale`);

--
-- Index pour la table `weapon_exceptions`
--
ALTER TABLE `weapon_exceptions`
  ADD PRIMARY KEY (`dofus_dude_id`,`weapon_area_effect_id`),
  ADD KEY `fk_weapon_exceptions_weapon_area_effect` (`weapon_area_effect_id`);

--
-- Index pour la table `webhook_almanaxes`
--
ALTER TABLE `webhook_almanaxes`
  ADD PRIMARY KEY (`guild_id`,`channel_id`,`game`),
  ADD UNIQUE KEY `uni_webhook_almanaxes_webhook_id` (`webhook_id`);

--
-- Index pour la table `webhook_feeds`
--
ALTER TABLE `webhook_feeds`
  ADD PRIMARY KEY (`guild_id`,`channel_id`,`feed_type_id`,`game`),
  ADD UNIQUE KEY `uni_webhook_feeds_webhook_id` (`webhook_id`),
  ADD KEY `fk_webhook_feeds_feed_type` (`feed_type_id`);

--
-- Index pour la table `webhook_twitters`
--
ALTER TABLE `webhook_twitters`
  ADD PRIMARY KEY (`guild_id`,`channel_id`,`twitter_id`,`game`),
  ADD UNIQUE KEY `uni_webhook_twitters_webhook_id` (`webhook_id`),
  ADD KEY `fk_webhook_twitters_twitter_account` (`twitter_id`);

--
-- Contraintes pour les tables déchargées
--

--
-- Contraintes pour la table `alignment_books`
--
ALTER TABLE `alignment_books`
  ADD CONSTRAINT `fk_alignment_books_city` FOREIGN KEY (`city_id`,`game`) REFERENCES `cities` (`id`, `game`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_alignment_books_order` FOREIGN KEY (`order_id`,`game`) REFERENCES `orders` (`id`, `game`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_alignment_books_server` FOREIGN KEY (`server_id`) REFERENCES `servers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `channel_servers`
--
ALTER TABLE `channel_servers`
  ADD CONSTRAINT `fk_channel_servers_guild` FOREIGN KEY (`guild_id`,`game`) REFERENCES `guilds` (`id`, `game`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_channel_servers_server` FOREIGN KEY (`server_id`) REFERENCES `servers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `characteristics`
--
ALTER TABLE `characteristics`
  ADD CONSTRAINT `fk_characteristic_emoji` FOREIGN KEY (`id`,`emoji_type`) REFERENCES `emojis` (`id`, `type`) ON DELETE RESTRICT ON UPDATE RESTRICT;

--
-- Contraintes pour la table `cities`
--
ALTER TABLE `cities`
  ADD CONSTRAINT `fk_city_emoji` FOREIGN KEY (`id`,`emoji_type`) REFERENCES `emojis` (`id`, `type`) ON DELETE RESTRICT ON UPDATE RESTRICT;

--
-- Contraintes pour la table `city_labels`
--
ALTER TABLE `city_labels`
  ADD CONSTRAINT `city_labels_ibfk_1` FOREIGN KEY (`city_id`,`game`) REFERENCES `cities` (`id`, `game`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `equipment_type_weapon_area_effects`
--
ALTER TABLE `equipment_type_weapon_area_effects`
  ADD CONSTRAINT `fk_equipment_type_weapon_area_effects_weapon_area_effect` FOREIGN KEY (`weapon_area_effect_id`) REFERENCES `weapon_area_effects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `feed_sources`
--
ALTER TABLE `feed_sources`
  ADD CONSTRAINT `feed_sources_ibfk_1` FOREIGN KEY (`feed_type_id`) REFERENCES `feed_types` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `feed_type_labels`
--
ALTER TABLE `feed_type_labels`
  ADD CONSTRAINT `fk_feed_types_labels` FOREIGN KEY (`feed_type_id`) REFERENCES `feed_types` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `guilds`
--
ALTER TABLE `guilds`
  ADD CONSTRAINT `fk_guilds_server` FOREIGN KEY (`server_id`) REFERENCES `servers` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Contraintes pour la table `jobs`
--
ALTER TABLE `jobs`
  ADD CONSTRAINT `fk_job_emoji` FOREIGN KEY (`id`,`emoji_type`) REFERENCES `emojis` (`id`, `type`) ON DELETE RESTRICT ON UPDATE RESTRICT;

--
-- Contraintes pour la table `job_books`
--
ALTER TABLE `job_books`
  ADD CONSTRAINT `fk_job_books_job` FOREIGN KEY (`job_id`,`game`) REFERENCES `jobs` (`id`, `game`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_job_books_server` FOREIGN KEY (`server_id`) REFERENCES `servers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `job_labels`
--
ALTER TABLE `job_labels`
  ADD CONSTRAINT `fk_jobs_labels` FOREIGN KEY (`job_id`,`game`) REFERENCES `jobs` (`id`, `game`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `order_labels`
--
ALTER TABLE `order_labels`
  ADD CONSTRAINT `order_labels_ibfk_1` FOREIGN KEY (`order_id`,`game`) REFERENCES `orders` (`id`, `game`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `regex_characteristics`
--
ALTER TABLE `regex_characteristics`
  ADD CONSTRAINT `fk_regex_relative_characteristic_id` FOREIGN KEY (`relative_characteristic_id`) REFERENCES `characteristics` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `regex_characteristics_ibfk_1` FOREIGN KEY (`characteristic_id`) REFERENCES `characteristics` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `servers`
--
ALTER TABLE `servers`
  ADD CONSTRAINT `fk_server_emoji` FOREIGN KEY (`id`,`emoji_type`) REFERENCES `emojis` (`id`, `type`) ON DELETE RESTRICT ON UPDATE RESTRICT;

--
-- Contraintes pour la table `server_labels`
--
ALTER TABLE `server_labels`
  ADD CONSTRAINT `fk_servers_labels` FOREIGN KEY (`server_id`) REFERENCES `servers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `weapon_area_effects`
--
ALTER TABLE `weapon_area_effects`
  ADD CONSTRAINT `weapon_area_effects_ibfk_1` FOREIGN KEY (`id`,`emoji_type`) REFERENCES `emojis` (`id`, `type`) ON DELETE RESTRICT ON UPDATE RESTRICT;

--
-- Contraintes pour la table `weapon_area_effect_labels`
--
ALTER TABLE `weapon_area_effect_labels`
  ADD CONSTRAINT `weapon_area_effect_labels_ibfk_1` FOREIGN KEY (`weapon_area_effect_id`) REFERENCES `weapon_area_effects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `weapon_exceptions`
--
ALTER TABLE `weapon_exceptions`
  ADD CONSTRAINT `fk_weapon_exceptions_weapon_area_effect` FOREIGN KEY (`weapon_area_effect_id`) REFERENCES `weapon_area_effects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `webhook_feeds`
--
ALTER TABLE `webhook_feeds`
  ADD CONSTRAINT `fk_webhook_feeds_feed_type` FOREIGN KEY (`feed_type_id`) REFERENCES `feed_types` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Contraintes pour la table `webhook_twitters`
--
ALTER TABLE `webhook_twitters`
  ADD CONSTRAINT `fk_webhook_twitters_twitter_account` FOREIGN KEY (`twitter_id`) REFERENCES `twitter_accounts` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
