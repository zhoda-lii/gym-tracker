-- Trigger #1: tgDeleteAttendanceOutsideGymHours
-- This trigger ensures records outside of gym hours are deleted from the Attendances table.
CREATE OR REPLACE TRIGGER tgDeleteAttendanceOutsideGymHours
BEFORE INSERT ON Attendances
FOR EACH ROW
DECLARE
    -- Convert SYSDATE Timezone to MST
    v_CurrentTime TIMESTAMP := FROM_TZ(SYSDATE, 'UTC') AT TIME ZONE 'US/Mountain';

    v_GymOpenTime    CONSTANT Attendances.CheckInTime%TYPE :=
        TO_TIMESTAMP(TO_CHAR(v_CurrentTime, 'DD-MON-YYYY') || ' ' ||
            '04:30:00', 'DD-MON-YYYY HH24:MI:SS');
    v_GymCloseTime   CONSTANT Attendances.CheckInTime%TYPE :=
        TO_TIMESTAMP(TO_CHAR(v_CurrentTime, 'DD-MON-YYYY') || ' ' ||
            '23:30:00', 'DD-MON-YYYY HH24:MI:SS');
    v_GymLastCheckIn CONSTANT Attendances.CheckInTime%TYPE :=
        v_GymCloseTime - INTERVAL '1' HOUR;
BEGIN
    -- Check if the CheckInTime falls outside gym hours
    IF :NEW.CheckInTime < v_GymOpenTime OR :NEW.CheckInTime > v_GymLastCheckIn THEN
        RAISE_APPLICATION_ERROR(-20113, 'TG1: Check-in is outside gym hours.');
    END IF;
END;
/


-- Trigger #2: tgPreventCheckinsWithoutCheckout
-- This trigger ensures that members cannot check in multiple times without clocking out first.
CREATE OR REPLACE TRIGGER tgPreventCheckinsWithoutCheckout
BEFORE INSERT ON Attendances
FOR EACH ROW
DECLARE
    v_count INTEGER;
BEGIN
    -- Check if the member has already checked in but not checked out
    SELECT COUNT(*)
    INTO v_count
    FROM Attendances
    WHERE MemberID = :NEW.MemberID
	AND TO_TIMESTAMP(AttendanceDate) = TO_TIMESTAMP(:NEW.AttendanceDate)
	AND CheckOutTime IS NULL;

    -- If such a record exists, raise an error
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'TG2: Please check-out first.');
    END IF;

    -- If no violations, the new row will be inserted
END;
/

-- Trigger #3: tgPreventIncorrectPayment
-- Ensures correct payment amounts based on trainer membership status.
CREATE OR REPLACE TRIGGER tgPreventIncorrectPayment
BEFORE INSERT ON Payments
FOR EACH ROW
DECLARE
    v_TrainerMbrID Members.TrainerMbrID%TYPE;
BEGIN
    -- Retrieve TrainerMbrID for the MemberID being inserted
    SELECT TrainerMbrID
    INTO v_TrainerMbrID
    FROM Members
    WHERE MemberID = :NEW.MemberID;

    -- Validate the Amount based on TrainerMbrID
    IF :NEW.Amount NOT IN (50, 100) THEN
        RAISE_APPLICATION_ERROR(-20002, 'TG3: Must be $50 or $100.');
    ELSIF v_TrainerMbrID IS NULL AND :NEW.Amount <> 50 THEN
        RAISE_APPLICATION_ERROR(-20003, 'TG3: Amount should be 50.');
    ELSIF v_TrainerMbrID IS NOT NULL AND :NEW.Amount <> 100 THEN
        RAISE_APPLICATION_ERROR(-20004, 'TG3: Amount should be 100.');
    END IF;

    -- If validations pass, the row is inserted automatically.
END;
/
