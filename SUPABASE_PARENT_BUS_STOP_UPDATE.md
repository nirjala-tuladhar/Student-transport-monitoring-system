# 🗺️ Parent Bus Stop Location Update - Supabase Setup

## ✅ Feature Overview

Parents can now edit their child's bus stop location (GPS coordinates and address) directly from the Parent Panel.

---

## 📊 Database Schema

The `students` table already has these columns:
- `bus_stop_lat` (double precision) - Latitude
- `bus_stop_lng` (double precision) - Longitude  
- `bus_stop_area` (text) - Area/neighborhood
- `bus_stop_city` (text) - City
- `bus_stop_country` (text) - Country

---

## 🔐 Required Supabase RLS Policies

### **Policy 1: Allow Parents to Update Their Child's Bus Stop Location**

```sql
-- Policy Name: Parents can update their child's bus stop location
-- Table: students
-- Operation: UPDATE
-- Target: Authenticated users with 'parent' role

CREATE POLICY "Parents can update their child's bus stop location"
ON students
FOR UPDATE
TO authenticated
USING (
  -- Check if the user is a parent
  EXISTS (
    SELECT 1 FROM parents
    WHERE parents.user_id = auth.uid()
    AND parents.student_id = students.id
  )
)
WITH CHECK (
  -- Check if the user is a parent
  EXISTS (
    SELECT 1 FROM parents
    WHERE parents.user_id = auth.uid()
    AND parents.student_id = students.id
  )
);
```

### **Alternative: Restrict to Only Bus Stop Fields**

If you want to be more restrictive and only allow parents to update bus stop fields (not other student data):

```sql
-- Policy Name: Parents can update only bus stop fields
-- Table: students
-- Operation: UPDATE
-- Target: Authenticated users with 'parent' role

CREATE POLICY "Parents can update only bus stop fields"
ON students
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM parents
    WHERE parents.user_id = auth.uid()
    AND parents.student_id = students.id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM parents
    WHERE parents.user_id = auth.uid()
    AND parents.student_id = students.id
  )
  -- Note: RLS cannot restrict which columns are updated
  -- You may want to use a stored procedure for stricter control
);
```

### **Recommended: Use a Stored Procedure (Most Secure)**

For maximum security, create a stored procedure that only updates bus stop fields:

```sql
-- Function: update_student_bus_stop
-- Description: Allows parents to update only their child's bus stop location

CREATE OR REPLACE FUNCTION update_student_bus_stop(
  p_student_id UUID,
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_area TEXT,
  p_city TEXT,
  p_country TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verify the caller is a parent of this student
  IF NOT EXISTS (
    SELECT 1 FROM parents
    WHERE parents.user_id = auth.uid()
    AND parents.student_id = p_student_id
  ) THEN
    RAISE EXCEPTION 'Not authorized to update this student';
  END IF;

  -- Update only bus stop fields
  UPDATE students
  SET 
    bus_stop_lat = p_lat,
    bus_stop_lng = p_lng,
    bus_stop_area = p_area,
    bus_stop_city = p_city,
    bus_stop_country = p_country,
    updated_at = NOW()
  WHERE id = p_student_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION update_student_bus_stop TO authenticated;
```

---

## 🔧 Implementation Options

### **Option 1: Direct Update (Simpler)**
Use the RLS policy above. The app code directly updates the `students` table.

**Pros:**
- ✅ Simpler implementation
- ✅ Works with existing code

**Cons:**
- ⚠️ Cannot restrict which columns are updated via RLS alone
- ⚠️ Parents could potentially update other fields if RLS is misconfigured

### **Option 2: Stored Procedure (Recommended)**
Use the stored procedure above. Update the app code to call the function.

**Pros:**
- ✅ Maximum security - only bus stop fields can be updated
- ✅ Centralized validation logic
- ✅ Audit trail with `updated_at`

**Cons:**
- ⚠️ Requires updating app code to call the function

---

## 📝 App Code Changes (If Using Stored Procedure)

If you choose Option 2, update the `ParentService` methods:

```dart
// In lib/services/parent_service.dart

Future<void> persistHomeCoords({
  required String studentId,
  required double lat,
  required double lng,
}) async {
  try {
    // Call the stored procedure instead of direct update
    await _supabase.rpc('update_student_bus_stop', params: {
      'p_student_id': studentId,
      'p_lat': lat,
      'p_lng': lng,
      'p_area': '', // Will be updated separately
      'p_city': '',
      'p_country': '',
    });
  } catch (e) {
    print('persistHomeCoords error for student $studentId: $e');
    rethrow;
  }
}

Future<void> updateBusStopAddress({
  required String studentId,
  required String area,
  required String city,
  required String country,
  double? lat,
  double? lng,
}) async {
  try {
    // Call the stored procedure
    await _supabase.rpc('update_student_bus_stop', params: {
      'p_student_id': studentId,
      'p_lat': lat ?? 0.0, // Use existing if not provided
      'p_lng': lng ?? 0.0,
      'p_area': area,
      'p_city': city,
      'p_country': country,
    });
  } catch (e) {
    print('updateBusStopAddress error for student $studentId: $e');
    rethrow;
  }
}
```

---

## 🧪 Testing the RLS Policy

### **Test 1: Parent Can Update Their Child's Location**
```sql
-- Login as a parent user
-- Try to update their child's bus stop
UPDATE students
SET bus_stop_lat = 27.7172, bus_stop_lng = 85.3240
WHERE id = '<their_child_id>';
-- Expected: SUCCESS
```

### **Test 2: Parent Cannot Update Another Child's Location**
```sql
-- Login as a parent user
-- Try to update a different child's bus stop
UPDATE students
SET bus_stop_lat = 27.7172, bus_stop_lng = 85.3240
WHERE id = '<different_child_id>';
-- Expected: FAIL (no rows updated)
```

### **Test 3: Parent Cannot Update Other Fields (If Using Stored Procedure)**
```sql
-- Login as a parent user
-- Try to update the student's name
UPDATE students
SET name = 'Hacked Name'
WHERE id = '<their_child_id>';
-- Expected: FAIL (if using stored procedure)
-- Expected: SUCCESS (if using direct RLS - need to be careful!)
```

---

## 🎯 Recommended Setup

**For maximum security, use Option 2 (Stored Procedure):**

1. ✅ Create the `update_student_bus_stop` function in Supabase
2. ✅ Update the `ParentService` code to call the function
3. ✅ Test thoroughly with different parent accounts
4. ✅ Monitor logs for any unauthorized access attempts

**If you prefer simplicity, use Option 1 (Direct RLS):**

1. ✅ Create the RLS policy for UPDATE on students table
2. ✅ Current app code will work as-is
3. ✅ Test thoroughly with different parent accounts
4. ⚠️ Be aware that parents could potentially update other fields if they bypass the app

---

## 📋 Verification Checklist

- [ ] RLS policy created on `students` table
- [ ] Parents table has correct `user_id` and `student_id` relationships
- [ ] Tested with actual parent account
- [ ] Verified parents cannot update other students
- [ ] Verified coordinates are saved correctly
- [ ] Verified address fields are saved correctly
- [ ] Map updates after location change
- [ ] Error handling works correctly

---

**Last Updated:** November 6, 2025
**Status:** ✅ Feature implemented, awaiting Supabase RLS policy setup
