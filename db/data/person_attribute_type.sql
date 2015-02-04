-- MySQL dump 10.13  Distrib 5.5.38, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: openmrs_17
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
-- Table structure for table `person_attribute_type`
--

DROP TABLE IF EXISTS `person_attribute_type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `person_attribute_type` (
  `person_attribute_type_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL DEFAULT '',
  `description` text NOT NULL,
  `format` varchar(50) DEFAULT NULL,
  `foreign_key` int(11) DEFAULT NULL,
  `searchable` smallint(6) NOT NULL DEFAULT '0',
  `creator` int(11) NOT NULL DEFAULT '0',
  `date_created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `changed_by` int(11) DEFAULT NULL,
  `date_changed` datetime DEFAULT NULL,
  `retired` smallint(6) NOT NULL DEFAULT '0',
  `retired_by` int(11) DEFAULT NULL,
  `date_retired` datetime DEFAULT NULL,
  `retire_reason` varchar(255) DEFAULT NULL,
  `edit_privilege` varchar(255) DEFAULT NULL,
  `uuid` char(38) NOT NULL,
  `sort_weight` double DEFAULT NULL,
  PRIMARY KEY (`person_attribute_type_id`),
  UNIQUE KEY `person_attribute_type_uuid_index` (`uuid`),
  KEY `name_of_attribute` (`name`),
  KEY `type_creator` (`creator`),
  KEY `attribute_type_changer` (`changed_by`),
  KEY `attribute_is_searchable` (`searchable`),
  KEY `user_who_retired_person_attribute_type` (`retired_by`),
  KEY `person_attribute_type_retired_status` (`retired`),
  KEY `privilege_which_can_edit` (`edit_privilege`),
  CONSTRAINT `attribute_type_changer` FOREIGN KEY (`changed_by`) REFERENCES `users` (`user_id`),
  CONSTRAINT `attribute_type_creator` FOREIGN KEY (`creator`) REFERENCES `users` (`user_id`),
  CONSTRAINT `privilege_which_can_edit` FOREIGN KEY (`edit_privilege`) REFERENCES `privilege` (`privilege`),
  CONSTRAINT `user_who_retired_person_attribute_type` FOREIGN KEY (`retired_by`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=35 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `person_attribute_type`
--

LOCK TABLES `person_attribute_type` WRITE;
/*!40000 ALTER TABLE `person_attribute_type` DISABLE KEYS */;
INSERT INTO `person_attribute_type` VALUES (1,'Race','Group of persons related by common descent or heredity','java.lang.String',NULL,0,1,'2007-11-28 08:11:37',NULL,NULL,0,NULL,NULL,NULL,NULL,'8d871386-c2cc-11de-8d13-0010c6dffd0f',29),(2,'Birthplace','Location of persons birth','java.lang.String',NULL,0,1,'2007-11-28 08:11:37',NULL,NULL,0,NULL,NULL,NULL,NULL,'8d8718c2-c2cc-11de-8d13-0010c6dffd0f',4),(3,'Citizenship','Country of which this person is a member','java.lang.String',NULL,0,1,'2007-11-28 08:11:37',NULL,NULL,0,NULL,NULL,NULL,NULL,'8d871afc-c2cc-11de-8d13-0010c6dffd0f',6),(4,'Mother\'s Name','First or last name of this person\'s mother','java.lang.String',NULL,0,1,'2007-11-28 08:11:37',NULL,NULL,0,NULL,NULL,NULL,NULL,'8d871d18-c2cc-11de-8d13-0010c6dffd0f',19),(5,'Civil Status','Marriage status of this person','org.openmrs.Concept',NULL,0,1,'2007-11-28 08:11:37',NULL,NULL,0,NULL,NULL,NULL,NULL,'8d871f2a-c2cc-11de-8d13-0010c6dffd0f',7),(6,'Health District','District/region in which this patient\' home health center resides','java.lang.String',NULL,0,1,'2007-11-28 08:11:37',NULL,NULL,0,NULL,NULL,NULL,NULL,'8d872150-c2cc-11de-8d13-0010c6dffd0f',12),(7,'Health Center','Specific Location of this person\'s home health center.','org.openmrs.Location',NULL,0,1,'2007-11-28 08:11:37',NULL,NULL,0,NULL,NULL,NULL,NULL,'8d87236c-c2cc-11de-8d13-0010c6dffd0f',11),(8,'Treatment Supporter','','java.lang.String',NULL,1,1,'2008-09-23 23:12:59',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f85764-2d83-11d8-a871-0024217bb78e',32),(9,'MDR-TB Patient Contact ID Number','Used by the mdrtb module to give non-patient contacts an ID number.','java.lang.String',NULL,0,1,'2008-09-23 23:35:12',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f859c6-2d83-11d8-a871-0024217bb78e',17),(10,'Home Village','The person\'s home village or place of origin','org.openmrs.Location',NULL,0,1,'2008-11-20 10:07:03',1,'2008-11-20 10:08:14',0,NULL,NULL,NULL,NULL,'a2f85c32-2d83-11d8-a871-0024217bb78e',14),(11,'Mother\'s Maiden Name','The maiden name of the person\'s mother.','java.lang.String',NULL,0,1,'2008-11-20 10:07:58',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f85ea8-2d83-11d8-a871-0024217bb78e',18),(12,'Cell Phone Number','Person primary cell phone number','java.lang.String',NULL,0,1,'2009-10-07 15:44:33',1,'2011-02-09 11:04:35',0,NULL,NULL,NULL,NULL,'a2f8618c-2d83-11d8-a871-0024217bb78e',5),(13,'Occupation','This is the current patient occupation','java.lang.String',NULL,0,1,'2009-10-09 15:45:21',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f86402-2d83-11d8-a871-0024217bb78e',24),(14,'Home Phone Number','Person home phone number, usually fixed line phone number','',NULL,0,1,'2009-11-11 11:43:28',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f8665a-2d83-11d8-a871-0024217bb78e',13),(15,'Office Phone Number','Person office phone number. Usually fixed line phone number','',NULL,0,1,'2009-11-11 11:44:39',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f868c6-2d83-11d8-a871-0024217bb78e',25),(16,'Place Of Birth','Description for birth place for a client in Maternity','java.lang.String',NULL,0,1,'2010-11-02 11:17:14',1,'2010-11-02 11:17:57',0,NULL,NULL,NULL,NULL,'a2f86b28-2d83-11d8-a871-0024217bb78e',26),(17,'Ancestral Traditional Authority','T/A ','java.lang.String',NULL,0,1,'2010-11-02 11:18:29',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f86d8a-2d83-11d8-a871-0024217bb78e',2),(18,'Current Place Of Residence','Place of stay','java.lang.String',NULL,0,1,'2010-11-02 11:19:13',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f86fec-2d83-11d8-a871-0024217bb78e',9),(19,'Landmark Or Plot Number','Landmark or plot number','java.lang.String',NULL,0,1,'2010-11-02 11:19:43',1,'2010-11-02 11:19:55',0,NULL,NULL,NULL,NULL,'a2f8723a-2d83-11d8-a871-0024217bb78e',16),(20,'Agrees to phone text for TB therapy','This question asked at registration to ascertain if person agrees to be sent phone text messages for TB therapy','',NULL,0,1,'2011-04-26 11:32:17',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f8749c-2d83-11d8-a871-0024217bb78e',1),(21,'Agrees to be visited at home for TB therapy','This asked at registration to ascertain if person agrees to home visit by HCW for TB therapy','',NULL,0,1,'2011-04-26 11:33:34',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f87708-2d83-11d8-a871-0024217bb78e',0),(23,'ART status at registration','ART status of this person at registration','org.openmrs.Concept',NULL,0,1,'2011-04-26 11:34:48',1,'2011-06-13 21:49:08',0,NULL,NULL,NULL,NULL,'a2f8796a-2d83-11d8-a871-0024217bb78e',3),(24,'NEXT OF KIN','A patient\'s next of kin','',NULL,0,1,'2011-05-30 10:14:04',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f87bd6-2d83-11d8-a871-0024217bb78e',21),(25,'NEXT OF KIN CONTACT NUMBER','A patient\'s next of kin contact number','',NULL,0,1,'2011-05-30 10:14:45',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f87e2e-2d83-11d8-a871-0024217bb78e',22),(26,'Source of referral','The source of referral for this person. Could be self. health facility etc','',NULL,0,1,'2011-05-31 11:22:24',1,'2011-06-01 15:35:54',0,NULL,NULL,NULL,NULL,'a2f8807c-2d83-11d8-a871-0024217bb78e',31),(27,'Number of TB contacts','Number of people TB patient is in contact with within a household','',NULL,0,1,'2011-06-01 19:24:53',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f882e8-2d83-11d8-a871-0024217bb78e',23),(28,'EDUCATION LEVEL','Maternity required this field','',NULL,0,1,'2011-07-18 17:20:50',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f89af8-2d83-11d8-a871-0024217bb78e',10),(29,'Religion','Maternity required this field','',NULL,0,1,'2011-07-18 17:21:11',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f89d6e-2d83-11d8-a871-0024217bb78e',30),(30,'Nearest health facility','The callers closest health facility in mnch hotline','java.lang.String',NULL,0,1,'2012-07-18 23:49:08',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f89fc6-2d83-11d8-a871-0024217bb78e',20),(31,'Provider Title','To keep birth report providers','',NULL,0,1,'2002-10-31 21:39:39',1,'2002-10-31 21:40:11',0,NULL,NULL,NULL,NULL,'a2f8a228-2d83-11d8-a871-0024217bb78e',28),(32,'Hospital Date','To trace birth report provider health centers','',NULL,0,1,'2002-10-31 21:41:15',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f8a48a-2d83-11d8-a871-0024217bb78e',15),(33,'Provider Name','','',NULL,0,1,'2002-10-31 21:41:35',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f8a6d8-2d83-11d8-a871-0024217bb78e',27),(34,'Country of Residence','Stores actual country a person/patient is residing','',NULL,0,1,'2003-11-07 19:11:12',NULL,NULL,0,NULL,NULL,NULL,NULL,'a2f8a930-2d83-11d8-a871-0024217bb78e',8);
/*!40000 ALTER TABLE `person_attribute_type` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2014-10-03 18:29:42
