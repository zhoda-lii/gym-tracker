-- View #1: vwMemberInitialWeight (Member View)
-- This view allows members to check their initial weight.
CREATE OR REPLACE VIEW vwMemberInitialWeight
AS 
    SELECT  fr.MemberID, 
            fr.RecordDate, 
            fr.WeightLbs
    FROM FitnessRecords fr
    INNER JOIN (
        SELECT MemberID, MIN(RecordDate) AS InitialRecordDate
        FROM FitnessRecords
        GROUP BY MemberID) initialfr
    ON fr.MemberID = initialfr.MemberID AND fr.RecordDate = initialfr.InitialRecordDate;
/

-- View #2: vwMemberLatestWeight (Member View)
-- This view allows members to check their latest weight.
CREATE OR REPLACE VIEW vwMemberLatestWeight
AS
    SELECT  fr.MemberID,
            fr.RecordDate,
            fr.WeightLbs
    FROM FitnessRecords fr
    INNER JOIN (
        SELECT MemberID, MAX(RecordDate) AS InitialRecordDate
        FROM FitnessRecords
        GROUP BY MemberID) latestfr
    ON fr.MemberID = latestfr.MemberID AND fr.RecordDate = latestfr.InitialRecordDate;
/

-- View #3: vwMemberInitialVsLatest (Member View) - (View #1+2)
-- This view allows members to see both their initial and latest weights.
CREATE OR REPLACE VIEW vwMemberInitialVsLatest
AS
    SELECT i.MemberID,
           i.RecordDate AS InitialRecordDate, 
           i.WeightLbs AS InitialWeightLbs,
           l.RecordDate AS LatestRecordDate, 
           l.WeightLbs AS LatestWeightLbs
    FROM vwMemberInitialWeight i
    INNER JOIN vwMemberLatestWeight l
    ON i.MemberID = l.MemberID;
/

-- View #4: vwMemberLatestStatus (Member View)
-- This view allows members to review their membership status and track their latest progress.
CREATE OR REPLACE VIEW vwMemberLatestStatus
AS
	SELECT m.MemberID, m.FirstName, m.LastName, m.Gender, m.DateOfBirth,
		   m.MembershipStart, m.MembershipEnd,
		   vs.InitialRecordDate, vs.InitialWeightLbs,
		   vs.LatestRecordDate, vs.LatestWeightLbs
	FROM Members m
	LEFT JOIN vwMemberInitialVsLatest vs
	ON m.MemberID = vs.MemberID;
/

-- View #5: vwTrainerNutritionTraining (Trainer View)
-- This view allows trainers to tailor workouts, monitor nutrition intake, and optimize training plans.
CREATE OR REPLACE VIEW vwTrainerNutritionTraining
AS
    SELECT  m.MemberID, fr.RecordDate, 
            m.FirstName, m.LastName, m.DateOfBirth, m.Gender,
			GetCalorieMaintenance(fr.RecordDate, m.MemberID) AS CalorieMaintenance,
            fr.CalorieIntake, fr.WeightLbs, fr.HeightInches,
			GetBMIValue(fr.HeightInches, fr.WeightLbs) AS BMIValue,
			GetBMIClass(GetBMIValue(fr.HeightInches, fr.WeightLbs)) AS BMIClass,
			e.EquipmentName, e.EquipmentType, u.UsageStart, u.UsageEnd
    FROM Members m
    JOIN FitnessRecords fr
        ON m.MemberID = fr.MemberID
    JOIN EquipmentUsages u
        ON m.MemberID = u.MemberID AND u.UsageDate = fr.RecordDate
    JOIN Equipments e
        ON u.EquipmentID = e.EquipmentID;
/

-- View #6: vwFinanceMembershipPayment (Finance View)
-- This view allows finance staff to monitor payment statuses, track membership durations.
CREATE OR REPLACE VIEW vwFinanceMembershipPayment
AS
    SELECT m.MemberID, m.FirstName, m.LastName,
		m.MembershipStart, m.MembershipEnd, m.MembershipType,
        p.PaymentID, p.PaymentDate, p.Amount, p.PaymentMethod
    FROM Members m
    LEFT JOIN Payments p
	ON m.MemberID = p.MemberID;
/
