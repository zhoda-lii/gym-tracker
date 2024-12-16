-- Function #1: GetCalorieMaintenance
-- Function to get Calorie Maintenance
CREATE OR REPLACE FUNCTION GetCalorieMaintenance (
    p_RecordDate IN FitnessRecords.RecordDate%TYPE,
    p_MemberID IN Members.MemberID%TYPE
) RETURN DECIMAL AS
    -- Declare variables for Gender, DOB (Age), WeightLbs, HeightInches
    v_Gender Members.Gender%TYPE;
    v_DOB Members.DateOfBirth%TYPE;
    v_Age NUMBER;
    v_WeightLbs FitnessRecords.WeightLbs%TYPE;
    v_HeightInches FitnessRecords.HeightInches%TYPE;
    v_WeightKg FitnessRecords.WeightLbs%TYPE;
    v_HeightCm FitnessRecords.HeightInches%TYPE;
    v_BMR DECIMAL(10, 2);
    v_CalorieMaintenance DECIMAL(10, 2);
BEGIN
    -- Get Gender and Date of Birth (DOB)
    SELECT Gender, DateOfBirth
	INTO v_Gender, v_DOB
    FROM Members
    WHERE MemberID = p_MemberID;

    -- Calculate Age
    v_Age := TRUNC(MONTHS_BETWEEN(p_RecordDate, v_DOB) / 12);

    -- Get WeightLbs and HeightInches from FitnessRecords
    SELECT WeightLbs, HeightInches
	INTO v_WeightLbs, v_HeightInches
    FROM FitnessRecords
    WHERE RecordDate = p_RecordDate AND MemberID = p_MemberID;

    -- Convert Weight to Kilograms and Height to Centimeters
    v_WeightKg := v_WeightLbs / 2.204623;
    v_HeightCm := v_HeightInches * 2.54;

    -- Calculate Basal Metabolic Rate (BMR) based on gender
    IF v_Gender = 'M' THEN
        v_BMR := (10 * v_WeightKg) + (6.25 * v_HeightCm) - (5 * v_Age) + 5;
    ELSE
        v_BMR := (10 * v_WeightKg) + (6.25 * v_HeightCm) - (5 * v_Age) - 161;
    END IF;

    -- Calculate TDEE (Calorie Maintenance) based on BMR and activity level
	-- Total Daily Energy Expenditure is how much energy you burn each day
	-- which is basically equivalent to the amount of calories your body needs to maintain weight
    v_CalorieMaintenance := v_BMR * 1.55; -- Moderately active

    -- Return the calculated Calorie Maintenance value
    RETURN v_CalorieMaintenance;

EXCEPTION
    WHEN OTHERS THEN
        -- Handle any potential errors (e.g., if the SELECT queries return no rows)
        RETURN NULL;
END GetCalorieMaintenance;
/

-- Function #2: GetBMIValue
-- Function to calculate the BMI Value
CREATE OR REPLACE FUNCTION GetBMIValue (
    p_HeightInches IN FitnessRecords.HeightInches%TYPE,
    p_WeightLbs IN FitnessRecords.WeightLbs%TYPE
) RETURN DECIMAL AS
    v_BMI DECIMAL(10, 2);
BEGIN
    -- Calculate BMI using the formula (Weight / Height^2) * 703
    v_BMI := (p_WeightLbs / POWER(p_HeightInches, 2)) * 703;
    
    -- Return the calculated BMI value
    RETURN v_BMI;
EXCEPTION
    WHEN OTHERS THEN
        -- Handle any potential errors
        RETURN NULL;
END GetBMIValue;
/

-- Function #3: GetBMIClass
-- Function to determine the BMI classification
CREATE OR REPLACE FUNCTION GetBMIClass (
    p_BMI IN DECIMAL
) RETURN VARCHAR AS
    v_BMICategory VARCHAR(50);
BEGIN
    -- Initialize the category variable
    v_BMICategory := NULL;
    
    -- Determine BMI category
    IF p_BMI < 18.5 THEN
        v_BMICategory := 'Underweight';
    ELSIF p_BMI >= 18.5 AND p_BMI < 25 THEN
        v_BMICategory := 'Normal';
    ELSIF p_BMI >= 25 AND p_BMI < 30 THEN
        v_BMICategory := 'Overweight';
    ELSIF p_BMI >= 30 THEN
        v_BMICategory := 'Obese';
    END IF;

    -- Return the determined category
    RETURN v_BMICategory;
EXCEPTION
    WHEN OTHERS THEN
        -- Handle any potential errors
        RETURN NULL;
END GetBMIClass;
/
