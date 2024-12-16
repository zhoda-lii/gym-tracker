-- Step 1. Delete Tables (if existing)
-- Ensures that any dependent constraints (like foreign keys) are removed along with the table
DROP TABLE EquipmentUsages CASCADE CONSTRAINTS;
DROP TABLE FitnessRecords CASCADE CONSTRAINTS;
DROP TABLE Payments CASCADE CONSTRAINTS;
DROP TABLE Attendances CASCADE CONSTRAINTS;
DROP TABLE Equipments CASCADE CONSTRAINTS;
DROP TABLE Members CASCADE CONSTRAINTS;

-- Step 2. Create Tables, one by one, and add constraints (PK, NULLs, `s)
-- Create the Members table
CREATE TABLE Members (
    MemberID NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    FirstName VARCHAR2(50)	NOT NULL,
    LastName VARCHAR2(50)	NOT NULL,
    Gender CHAR(1)			NOT NULL,
    Email VARCHAR2(50),
    Phone VARCHAR2(20)		NOT NULL,
    DateOfBirth DATE		NOT NULL,
    MembershipStart DATE,
    MembershipEnd DATE,
    MembershipType VARCHAR2(10),
    TrainerMbrID NUMBER
);
-- Create the Payments table
CREATE TABLE Payments (
    PaymentID NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PaymentDate DATE			NOT NULL,
    Amount NUMBER(10, 2)		NOT NULL,
    PaymentMethod VARCHAR2(50)	NOT NULL,
    MemberID NUMBER				NOT NULL
);
-- Create the Attendances table
CREATE TABLE Attendances (
    AttendanceID NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    AttendanceDate DATE		NOT NULL,
    CheckInTime TIMESTAMP	NOT NULL,
    CheckOutTime TIMESTAMP,
    MemberID NUMBER			NOT NULL
);
-- Create the Equipments table
CREATE TABLE Equipments (
    EquipmentID NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    EquipmentName VARCHAR2(50) NOT NULL,
    EquipmentType VARCHAR2(50) NOT NULL
);
-- Create the EquipmentUsages table
CREATE TABLE EquipmentUsages (
    UsageDate DATE			NOT NULL,
    MemberID NUMBER			NOT NULL,
    EquipmentID NUMBER		NOT NULL,
    UsageStart TIMESTAMP	NOT NULL,
    UsageEnd TIMESTAMP,
	-- Member can use each equipment once per day:
	--   MemberID + UsageDate + EquipmentID must be unique
    PRIMARY KEY (UsageDate, MemberID, EquipmentID)
);
-- Create the FitnessRecords table
CREATE TABLE FitnessRecords (
    RecordDate DATE				NOT NULL,
    MemberID NUMBER				NOT NULL,
    CalorieIntake NUMBER(10, 2) NOT NULL,
    WeightLbs NUMBER(10, 2)		NOT NULL,
    HeightInches NUMBER(10, 2)	NOT NULL,
    PRIMARY KEY (RecordDate, MemberID)
);

-- Step 3: Add Foreign Key and Check constraints
-- For the Members table
ALTER TABLE Members
ADD CONSTRAINT fkMembersMbrID FOREIGN KEY (TrainerMbrID) REFERENCES Members(MemberID);
ALTER TABLE Members
ADD CONSTRAINT chkMembersGender CHECK (Gender IN ('M', 'F'));
ALTER TABLE Members
ADD CONSTRAINT chkMembersMembershipType CHECK (MembershipType IN ('Standard', 'Premium'));

-- For the Payments table
ALTER TABLE Payments
ADD CONSTRAINT fkPaymentsMbrID FOREIGN KEY (MemberID) REFERENCES Members(MemberID);
ALTER TABLE payments
ADD CONSTRAINT chkPaymentsAmount CHECK (Amount IN (50, 100));
ALTER TABLE payments
ADD CONSTRAINT chkPaymentsPaymentMethod CHECK (PaymentMethod IN ('Cash', 'Debit Card', 'Credit Card'));

-- For the Attendances table
ALTER TABLE Attendances
ADD CONSTRAINT fkAttendancesMbrID FOREIGN KEY (MemberID) REFERENCES Members(MemberID);

-- For the EquipmentUsages table
ALTER TABLE EquipmentUsages
ADD CONSTRAINT fkEquipUsagesMembID FOREIGN KEY (MemberID) REFERENCES Members(MemberID);
ALTER TABLE EquipmentUsages
ADD CONSTRAINT fkEquipUsagesEquipID FOREIGN KEY (EquipmentID) REFERENCES Equipments(EquipmentID);

-- For the FitnessRecords table
ALTER TABLE FitnessRecords
ADD CONSTRAINT fkFitnessRecordsMbrID FOREIGN KEY (MemberID) REFERENCES Members(MemberID);
