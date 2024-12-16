-- Stored Procedure #1: spAddMember
-- This stored procedure is responsible for adding a new member to the database.
CREATE OR REPLACE PROCEDURE spAddMember (
    p_FirstName       Members.FirstName%TYPE,
    p_LastName        Members.LastName%TYPE,
    p_Gender          Members.Gender%TYPE,
    p_Email           Members.Email%TYPE DEFAULT NULL,
    p_Phone           Members.Phone%TYPE,
    p_DateOfBirth     Members.DateOfBirth%TYPE,
    p_TrainerMbrID    Members.TrainerMbrID%TYPE DEFAULT NULL
) IS
    v_tmpMemberID     Members.MemberID%TYPE;
BEGIN
    -- Check if mandatory fields are provided
    IF p_FirstName IS NULL OR p_LastName IS NULL OR p_Gender IS NULL 
       OR p_Phone IS NULL OR p_DateOfBirth IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Mandatory fields cannot be null.');
    END IF;

    -- Insert member into Members table
    INSERT INTO Members (
        FirstName, LastName, Gender, Email, Phone, DateOfBirth, TrainerMbrID
    ) VALUES (
        p_FirstName, p_LastName, p_Gender, p_Email, p_Phone, p_DateOfBirth, p_TrainerMbrID
    );

    -- Print success message
    SELECT MAX(MemberID) INTO v_tmpMemberID FROM Members;
    DBMS_OUTPUT.PUT_LINE('Member successfully added. Your Member ID is: ' || v_tmpMemberID);

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
        RAISE;
END spAddMember;
/

-- Stored Procedure #2: spAddPaymentUpdateMembership
-- This stored procedure is responsible for adding a payment record then updating the membership info of the member.
CREATE OR REPLACE PROCEDURE spAddPaymentUpdateMembership (
    p_MemberID       IN Members.MemberID%TYPE,
    p_PaymentAmount  IN Payments.Amount%TYPE,
    p_PaymentMethod  IN Payments.PaymentMethod%TYPE
) AS
    v_PaymentDate      Payments.PaymentDate%TYPE := SYSDATE; -- Assume current date for payment
    v_MembershipStart  Members.MembershipStart%TYPE;
    v_MembershipEnd    Members.MembershipEnd%TYPE;
    v_MembershipType   Members.MembershipType%TYPE;
    v_OldMembershipStart  Members.MembershipStart%TYPE;
BEGIN
    -- Check if mandatory fields are provided
    IF p_MemberID IS NULL OR p_PaymentAmount IS NULL OR p_PaymentMethod IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'MemberID and Payment Info cannot be null.');
    END IF;

     -- Check if the member exists
    BEGIN
        SELECT MembershipStart
        INTO v_OldMembershipStart
        FROM Members
        WHERE MemberID = p_MemberID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'Member ID does not exist.');
    END;

    -- Add payment record
    INSERT INTO Payments (
        PaymentDate, Amount, PaymentMethod, MemberID
    ) VALUES (
        v_PaymentDate, p_PaymentAmount, p_PaymentMethod, p_MemberID
    );

    -- Calculate MembershipEnd date
    -- (one day before the end of the month following MembershipStart date)
    v_MembershipStart := NVL(v_OldMembershipStart, v_PaymentDate);
    v_MembershipEnd := ADD_MONTHS(v_MembershipStart, 1) - 1;

    -- Check if membership is standard or premium
    IF p_PaymentAmount = 50 THEN
        v_MembershipType := 'Standard';
    ELSIF p_PaymentAmount = 100 THEN
        v_MembershipType := 'Premium';
    ELSE
        RAISE_APPLICATION_ERROR(-20003, 'Invalid Payment Amount. Only 50 (Standard) or 100 (Premium) are allowed.');
    END IF;

    -- Update MembershipStart, MembershipEnd, and MembershipType columns in Members table
    UPDATE Members
    SET MembershipStart = v_MembershipStart,
        MembershipEnd   = v_MembershipEnd,
        MembershipType  = v_MembershipType
    WHERE MemberID = p_MemberID;

    -- Print success message
    DBMS_OUTPUT.PUT_LINE('Payment record added and membership details updated.');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
        RAISE;
END spAddPaymentUpdateMembership;
/

-- Stored Procedure #3: spMemberCheckIn
-- This stored procedure is responsible for member check-ins while checking active membership period.
CREATE OR REPLACE PROCEDURE spMemberCheckIn (
    p_MemberID IN Members.MemberID%TYPE
)
AS
    v_AttendanceDate Attendances.AttendanceDate%TYPE := SYSDATE;
    v_CheckInTime    Attendances.CheckInTime%TYPE := SYSTIMESTAMP;
    v_MembershipStart Members.MembershipStart%TYPE;
    v_MembershipEnd   Members.MembershipEnd%TYPE;
BEGIN
    -- Check if MemberID is provided
    IF p_MemberID IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'MemberID cannot be null.');
    END IF;

    -- Check if the member exists
    BEGIN
        SELECT MembershipStart, MembershipEnd
        INTO v_MembershipStart, v_MembershipEnd
        FROM Members
        WHERE MemberID = p_MemberID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'Member ID does not exist.');
    END;

    -- Check if the attendance date falls within the member's active membership period
    IF v_AttendanceDate < v_MembershipStart OR v_AttendanceDate > v_MembershipEnd THEN
        RAISE_APPLICATION_ERROR(-20003, 'Attendance date is not within the member''s active membership period.');
    END IF;

	-- Convert Timezone to MST
    v_CheckInTime := FROM_TZ(v_CheckInTime, 'UTC') AT TIME ZONE 'US/Mountain';

    -- Insert attendance record into the Attendances table
    INSERT INTO Attendances (AttendanceDate, CheckInTime, MemberID)
    VALUES (v_AttendanceDate, v_CheckInTime, p_MemberID);

    -- Success message
    DBMS_OUTPUT.PUT_LINE('Member successfully checked in.');
	
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
        RAISE;
END;
/

-- Stored Procedure #4: spMemberCheckOut
-- This stored procedure is responsible for member check-outs while checking active membership period.
CREATE OR REPLACE PROCEDURE spMemberCheckOut (
    p_MemberID IN Members.MemberID%TYPE
)
AS
    v_AttendanceDate Attendances.AttendanceDate%TYPE := SYSDATE; -- Current date without time
    v_CheckOutTime   Attendances.CheckInTime%TYPE := SYSTIMESTAMP; -- Current timestamp
    v_AttendanceID   Attendances.AttendanceID%TYPE;
    v_MembershipStart Members.MembershipStart%TYPE;
    v_MembershipEnd   Members.MembershipEnd%TYPE;
BEGIN
    -- Check if p_MemberID is provided
    IF p_MemberID IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'MemberID cannot be null.');
    END IF;

    -- Check if the member exists and get MembershipStart and MembershipEnd dates
    BEGIN
        SELECT MembershipStart, MembershipEnd
        INTO v_MembershipStart, v_MembershipEnd
        FROM Members
        WHERE MemberID = p_MemberID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'Member ID does not exist.');
    END;

    -- Check if the attendance date falls within the member's active membership period
    IF v_AttendanceDate < v_MembershipStart OR v_AttendanceDate > v_MembershipEnd THEN
        RAISE_APPLICATION_ERROR(-20003, 'Attendance date is not within the member''s active membership period.');
    END IF;

    -- Check if there is an active attendance record (NULL CheckOutTime)
    BEGIN
        SELECT AttendanceID
        INTO v_AttendanceID
        FROM Attendances
        WHERE MemberID = p_MemberID
          AND TO_TIMESTAMP(AttendanceDate) = TO_TIMESTAMP(v_AttendanceDate)
          AND CheckOutTime IS NULL
        ORDER BY AttendanceDate, CheckInTime DESC
        FETCH FIRST ROW ONLY; -- Fetch only the latest attendance record
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20004, 'Member already clocked out or no active check-in found.');
    END;

	-- Convert Timezone to MST
    v_CheckOutTime := FROM_TZ(v_CheckOutTime, 'UTC') AT TIME ZONE 'US/Mountain';
	
    -- Update the latest attendance record with the checkout time
    UPDATE Attendances
    SET CheckOutTime = v_CheckOutTime
    WHERE AttendanceID = v_AttendanceID;

    -- Print success message
    DBMS_OUTPUT.PUT_LINE('Member successfully checked out.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
        RAISE;
END;
/

-- Stored Procedure #5: spAddFitnessRecord
-- This stored procedure is responsible for adding a fitness record to the database.
CREATE OR REPLACE PROCEDURE spAddFitnessRecord (
    p_MemberID      IN Members.MemberID%TYPE,
    p_CalorieIntake IN FitnessRecords.CalorieIntake%TYPE,
    p_WeightLbs      IN FitnessRecords.WeightLbs%TYPE,
    p_HeightInches   IN FitnessRecords.HeightInches%TYPE
)
AS
    v_RecordDate FitnessRecords.RecordDate%TYPE := SYSDATE;
    v_MembershipStart Members.MembershipStart%TYPE;
    v_MembershipEnd   Members.MembershipEnd%TYPE;
BEGIN
    -- Check if mandatory fields are provided
    IF p_MemberID IS NULL OR p_CalorieIntake IS NULL OR p_WeightLbs IS NULL OR p_HeightInches IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Mandatory fields cannot be null.');
    END IF;

    -- Check if the member exists and get MembershipStart and MembershipEnd dates
    BEGIN
        SELECT MembershipStart, MembershipEnd
        INTO v_MembershipStart, v_MembershipEnd
        FROM Members
        WHERE MemberID = p_MemberID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'Member ID does not exist.');
    END;

    -- Check if the record date falls within the member's active membership period
    IF v_RecordDate < v_MembershipStart OR v_RecordDate > v_MembershipEnd THEN
        RAISE_APPLICATION_ERROR(-20003, 'Record date is not within the member''s active membership period.');
    END IF;

    -- Insert fitness record data
    INSERT INTO FitnessRecords (RecordDate, MemberID, WeightLbs, HeightInches, CalorieIntake)
    VALUES (v_RecordDate, p_MemberID, p_WeightLbs, p_HeightInches, p_CalorieIntake);

    -- Print success message
    DBMS_OUTPUT.PUT_LINE('Fitness record successfully added. BMI is: ' || GetBMIClass(GetBMIValue(p_HeightInches, p_WeightLbs)));

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
        RAISE;
END;
/

-- Stored Procedure #6: spAddEquipmentUsageStart
-- This stored procedure is responsible for starting an equipment usage record to the database.
CREATE OR REPLACE PROCEDURE spAddEquipmentUsageStart (
    p_MemberID   IN Members.MemberID%TYPE,
    p_EquipmentID IN Equipments.EquipmentID%TYPE
)
AS
    v_UsageDate EquipmentUsages.UsageDate%TYPE := SYSDATE;  -- Current date and time
    v_UsageStart EquipmentUsages.UsageEnd%TYPE := SYSDATE; -- Current date and time
    v_MembershipStart Members.MembershipStart%TYPE;
    v_MembershipEnd   Members.MembershipEnd%TYPE;
    v_Exist NUMBER;
BEGIN
    -- Check if mandatory fields are provided
    IF p_MemberID IS NULL OR p_EquipmentID IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Mandatory fields cannot be null.');
    END IF;

    -- Check if the member exists and get MembershipStart and MembershipEnd dates
    BEGIN
        SELECT MembershipStart, MembershipEnd
        INTO v_MembershipStart, v_MembershipEnd
        FROM Members
        WHERE MemberID = p_MemberID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'Member ID does not exist.');
    END;

    -- Check if the equipment exists
    BEGIN
        SELECT 1
        INTO v_Exist
        FROM Equipments
        WHERE EquipmentID = p_EquipmentID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'Equipment ID does not exist.');
    END;

    -- Check if the usage date falls within the member's active membership period
    IF v_UsageDate < v_MembershipStart OR v_UsageDate > v_MembershipEnd THEN
        RAISE_APPLICATION_ERROR(-20004, 'Usage date is not within the member''s active membership period.');
    END IF;

    -- Insert equipment usage start record
    INSERT INTO EquipmentUsages
        (MemberID, UsageDate, UsageStart, UsageEnd, EquipmentID)
    VALUES
        (p_MemberID, v_UsageDate, v_UsageStart, NULL, p_EquipmentID);

    -- Print success message (Oracle DBMS_OUTPUT usage)
    DBMS_OUTPUT.PUT_LINE('Equipment usage start time successfully added.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
        RAISE;
END;
/

-- Stored Procedure #7: spAddEquipmentUsageEnd
-- This stored procedure is responsible for ending an equipment usage record to the database.
CREATE OR REPLACE PROCEDURE spAddEquipmentUsageEnd (
    p_MemberID    IN Members.MemberID%TYPE,
    p_EquipmentID IN Equipments.EquipmentID%TYPE
)
AS
    v_UsageDate EquipmentUsages.UsageDate%TYPE := SYSDATE;  -- Current date and time
    v_UsageEnd EquipmentUsages.UsageEnd%TYPE := SYSDATE;   -- Current date and time
    v_MembershipStart Members.MembershipStart%TYPE;
    v_MembershipEnd   Members.MembershipEnd%TYPE;
    v_Exists NUMBER;
BEGIN
    -- Check if mandatory fields are provided
    IF p_MemberID IS NULL OR p_EquipmentID IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Mandatory fields cannot be null.');
    END IF;

    -- Check if the member exists
    BEGIN
        SELECT MembershipStart, MembershipEnd
        INTO v_MembershipStart, v_MembershipEnd
        FROM Members
        WHERE MemberID = p_MemberID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'Member ID does not exist.');
    END;

    -- Check if the usage date falls within the member's active membership period
    IF v_UsageDate < v_MembershipStart OR v_UsageDate > v_MembershipEnd THEN
        RAISE_APPLICATION_ERROR(-20004, 'Usage date is not within the member''s active membership period.');
    END IF;

    -- Check if the equipment exists
    BEGIN
        SELECT 1
        INTO v_Exists
        FROM Equipments
        WHERE EquipmentID = p_EquipmentID
        FETCH FIRST 1 ROWS ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20004, 'Equipment ID does not exist.');
    END;

    -- Check if the equipment is being used by the member
    BEGIN
        SELECT 1
        INTO v_Exists
        FROM EquipmentUsages
        WHERE MemberID = p_MemberID
		AND EquipmentID = p_EquipmentID
        AND TO_TIMESTAMP(UsageDate) = TO_TIMESTAMP(v_UsageDate)
        FETCH FIRST 1 ROWS ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20005, 'Equipment ID not in use.');
    END;

    -- Check if the latest check-in has a NULL checkout
    BEGIN
        SELECT 1
        INTO v_Exists
        FROM EquipmentUsages
        WHERE MemberID = p_MemberID
        AND EquipmentID = p_EquipmentID
        AND TO_TIMESTAMP(UsageDate) = TO_TIMESTAMP(v_UsageDate)
        AND UsageEnd IS NULL
        ORDER BY UsageDate DESC, UsageStart DESC
        FETCH FIRST 1 ROWS ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006, 'End time already logged.');
    END;

    -- Update the end time for the equipment usage
    UPDATE EquipmentUsages
    SET UsageEnd = v_UsageEnd
    WHERE MemberID = p_MemberID
    AND EquipmentID = p_EquipmentID
    AND TO_TIMESTAMP(UsageDate) = TO_TIMESTAMP(v_UsageDate)
    AND UsageEnd IS NULL;

    -- Print success message
    DBMS_OUTPUT.PUT_LINE('Equipment usage end time successfully updated.');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
        RAISE;
END;
/
