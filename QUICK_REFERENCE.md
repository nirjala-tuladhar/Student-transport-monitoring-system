# Quick Reference - UI Redesign

## 🚀 5-Minute Quick Start

### 1. Import the essentials
```dart
import '../theme/app_theme.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/common_widgets.dart';
```

### 2. Wrap your screen
```dart
Scaffold(
  body: FadeInAnimation(
    child: YourContent(),
  ),
)
```

### 3. Use modern components
See cheat sheet below! 👇

---

## 📋 Component Cheat Sheet

### Text Fields
```dart
// ❌ OLD
TextFormField(
  controller: controller,
  decoration: InputDecoration(
    labelText: 'Email',
    prefixIcon: Icon(Icons.email),
  ),
)

// ✅ NEW
ModernTextField(
  controller: controller,
  label: 'Email Address',
  hint: 'Enter your email',
  prefixIcon: Icons.email_outlined,
)
```

### Buttons
```dart
// ❌ OLD
ElevatedButton(
  onPressed: _submit,
  child: Text('Submit'),
)

// ✅ NEW
AnimatedButton(
  text: 'Submit',
  onPressed: _submit,
  icon: Icons.check,
)
```

### Cards
```dart
// ❌ OLD
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
  ),
  child: content,
)

// ✅ NEW
AnimatedCard(
  onTap: () {},
  child: content,
)
```

### Loading States
```dart
// ❌ OLD
if (loading) CircularProgressIndicator()

// ✅ NEW
ShimmerLoading(
  width: double.infinity,
  height: 80,
)
```

### Empty States
```dart
// ❌ OLD
Center(child: Text('No data'))

// ✅ NEW
EmptyState(
  icon: Icons.inbox,
  title: 'No Data',
  message: 'Add items to get started',
)
```

---

## 🎨 Color Quick Reference

```dart
// Primary
AppTheme.primaryBlue      // #0066CC
AppTheme.accentTeal       // #02C39A

// Semantic
AppTheme.success          // Green
AppTheme.error            // Red
AppTheme.warning          // Orange
AppTheme.info             // Blue

// Text
AppTheme.textPrimary      // Dark
AppTheme.textSecondary    // Gray

// Background
AppTheme.backgroundLight  // Page BG
AppTheme.surfaceLight     // Card BG
```

---

## 📐 Spacing Quick Reference

```dart
SizedBox(height: AppTheme.spaceXSmall)  // 4px
SizedBox(height: AppTheme.spaceSmall)   // 8px
SizedBox(height: AppTheme.spaceMedium)  // 16px ⭐ Most common
SizedBox(height: AppTheme.spaceLarge)   // 24px
SizedBox(height: AppTheme.spaceXLarge)  // 32px
```

---

## 🎯 Common Patterns

### Dashboard Card
```dart
InfoCard(
  title: 'Total Students',
  value: '245',
  icon: Icons.people,
  color: AppTheme.primaryBlue,
  onTap: () => navigate(),
)
```

### Status Badge
```dart
StatusBadge(
  label: 'Active',
  color: AppTheme.success,
  icon: Icons.check_circle,
)
```

### Section Header
```dart
SectionHeader(
  title: 'Recent Activity',
  subtitle: 'Last 7 days',
  action: TextButton(
    onPressed: () {},
    child: Text('View All'),
  ),
)
```

### Loading Overlay
```dart
LoadingOverlay(
  isLoading: _isLoading,
  message: 'Processing...',
  child: YourContent(),
)
```

---

## 🎬 Animation Patterns

### Fade In on Load
```dart
FadeInAnimation(
  duration: AppTheme.normalAnimation,
  delay: Duration(milliseconds: 100),
  child: YourWidget(),
)
```

### Staggered Animations
```dart
Column(
  children: [
    FadeInAnimation(delay: Duration(milliseconds: 0), child: Item1()),
    FadeInAnimation(delay: Duration(milliseconds: 100), child: Item2()),
    FadeInAnimation(delay: Duration(milliseconds: 200), child: Item3()),
  ],
)
```

### Page Transition
```dart
Navigator.push(
  context,
  FadePageRoute(page: NextScreen()),
)
```

---

## 📱 Responsive Layout

```dart
final size = MediaQuery.of(context).size;
final isSmall = size.width < 600;
final isTablet = size.width >= 600 && size.width < 900;
final isDesktop = size.width >= 900;

Container(
  padding: EdgeInsets.all(isSmall ? 16 : 24),
  constraints: BoxConstraints(
    maxWidth: isDesktop ? 1200 : double.infinity,
  ),
)
```

---

## ✅ Pre-flight Checklist

Before committing your redesigned screen:

- [ ] Imports added
- [ ] FadeInAnimation wrapper
- [ ] Modern components used
- [ ] AppTheme colors used
- [ ] Consistent spacing
- [ ] Loading states added
- [ ] Empty states added
- [ ] Responsive layout
- [ ] Tested on mobile
- [ ] Tested on desktop
- [ ] All functionality works

---

## 🐛 Common Mistakes

### ❌ Don't Do This:
```dart
// Hard-coded colors
color: Colors.blue

// Hard-coded spacing
padding: EdgeInsets.all(15)

// No animation
Container(...)

// Basic TextField
TextFormField(...)
```

### ✅ Do This Instead:
```dart
// Theme colors
color: AppTheme.primaryBlue

// Design tokens
padding: EdgeInsets.all(AppTheme.spaceMedium)

// Animated
AnimatedCard(...)

// Modern component
ModernTextField(...)
```

---

## 💡 Pro Tips

1. **Consistency is key** - Use the same patterns everywhere
2. **Don't overdo animations** - Subtle is better
3. **Test responsiveness** - Check different screen sizes
4. **Use semantic colors** - success/error/warning
5. **Add loading states** - Users appreciate feedback
6. **Empty states matter** - Make them helpful
7. **Accessibility counts** - Good contrast, touch targets

---

## 📚 Full Documentation

- **Complete Guide:** `REDESIGN_GUIDE.md`
- **Visual Changes:** `VISUAL_CHANGES.md`
- **Summary:** `REDESIGN_SUMMARY.md`
- **Example:** `lib/screens/school_admin/login_screen.dart`

---

**Happy Redesigning! 🎨✨**
