-- MySQL dump 10.13  Distrib 5.5.38, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: openmrs_25
-- ------------------------------------------------------
-- Server version	5.5.38-0ubuntu0.14.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `drug_set`
--

DROP TABLE IF EXISTS `drug_set`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `drug_set` (
  `drug_set_id` int(11) NOT NULL AUTO_INCREMENT,
  `drug_inventory_id` int(11) DEFAULT NULL,
  `set_id` int(11) DEFAULT NULL,
  `frequency` varchar(255) NOT NULL,
  `duration` varchar(255) NOT NULL,
  `date_created` datetime DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL,
  `creator` int(11) DEFAULT NULL,
  `voided` tinyint(1) NOT NULL DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  `dose` float DEFAULT NULL,
  PRIMARY KEY (`drug_set_id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `drug_set`
--

LOCK TABLES `drug_set` WRITE;
/*!40000 ALTER TABLE `drug_set` DISABLE KEYS */;
INSERT INTO `drug_set` VALUES (1,275,1,'Once a day (OD)','30','2014-10-14 10:23:52','2014-10-14 10:23:52',1,0,NULL,1),(2,558,1,'Once a day (OD)','30','2014-10-14 11:04:01','2014-10-14 11:04:01',1,0,NULL,1),(3,559,1,'Once a day (OD)','30','2014-10-14 11:06:27','2014-10-14 11:06:27',1,0,NULL,2),(4,942,1,'Once a day (OD)','30','2014-10-14 11:25:17','2014-10-14 11:25:17',1,0,NULL,1),(5,943,1,'Once a day (OD)','30','2014-10-14 11:25:52','2014-10-14 11:25:52',1,0,NULL,2),(6,263,1,'Once a day (OD)','30','2014-10-14 11:27:04','2014-10-14 11:27:04',1,0,NULL,2),(7,812,1,'Once a day (OD)','30','2014-10-14 11:27:45','2014-10-14 11:27:45',1,0,NULL,1),(8,223,1,'Once a day (OD)','30','2014-10-14 11:28:33','2014-10-14 11:28:33',1,0,NULL,1),(9,266,1,'Once a day (OD)','30','2014-10-14 11:29:01','2014-10-14 11:29:01',1,0,NULL,2);
/*!40000 ALTER TABLE `drug_set` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `dset`
--

DROP TABLE IF EXISTS `dset`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dset` (
  `set_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` text,
  `description` text,
  `date_created` datetime DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL,
  `creator` int(11) NOT NULL,
  `status` varchar(25) NOT NULL,
  PRIMARY KEY (`set_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `dset`
--

LOCK TABLES `dset` WRITE;
/*!40000 ALTER TABLE `dset` DISABLE KEYS */;
INSERT INTO `dset` VALUES (1,'HTC Drugs','HT Drug','2014-10-14 10:23:52','2014-10-14 11:29:01',1,'active');
/*!40000 ALTER TABLE `dset` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2014-10-21  8:30:29
