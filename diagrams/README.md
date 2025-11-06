# 📊 PlantUML Diagrams for Student Transport Monitoring System

This folder contains all UML diagrams for the Student Transport Monitoring System.

---

## 📁 Diagram Files

### **Original Diagrams (Detailed):**
1. **`class_diagram.puml`** - Class Diagram (Full version with all attributes)
2. **`object_diagram.puml`** - Object Diagram (Multiple instances)
3. **`state_diagram.puml`** - State Diagram (With notes)
4. **`sequence_diagram.puml`** - Sequence Diagram (Detailed flow)
5. **`activity_diagram.puml`** - Activity Diagram (Complete workflow)
6. **`component_diagram.puml`** - Component Diagram
7. **`deployment_diagram.puml`** - Deployment Diagram
8. **`system_architecture.puml`** - System Architecture

### **Refined Diagrams (Simplified):**
1. **`refined_class_diagram.puml`** - Simplified class diagram
2. **`refined_object_diagram.puml`** - Simplified object diagram
3. **`refined_state_diagram.puml`** - Simplified state diagram
4. **`refined_sequence_diagram.puml`** - Simplified sequence diagram
5. **`refined_activity_diagram.puml`** - Simplified activity diagram

---

## 🎨 Diagram Features

All diagrams use:
- ✅ **Orthogonal lines** (straight, not curvy)
- ✅ **Clean layout** (not too complex)
- ✅ **Color-coded** (different colors for different diagram types)
- ✅ **Clear labels** (easy to understand)

---

## 🔧 How to View/Generate Diagrams

### **Option 1: Online PlantUML Editor (Easiest)**

1. Go to: **http://www.plantuml.com/plantuml/uml/**
2. Copy the content from any `.puml` file
3. Paste it into the editor
4. Click "Submit" to generate the diagram
5. Download as PNG, SVG, or PDF

### **Option 2: VS Code Extension**

1. Install **PlantUML** extension in VS Code
2. Open any `.puml` file
3. Press `Alt + D` to preview
4. Right-click → "Export Current Diagram" to save as image

### **Option 3: Command Line (Java Required)**

```bash
# Install PlantUML
# Download plantuml.jar from https://plantuml.com/download

# Generate PNG images
java -jar plantuml.jar diagrams/*.puml

# Generate SVG images
java -jar plantuml.jar -tsvg diagrams/*.puml

# Generate PDF
java -jar plantuml.jar -tpdf diagrams/*.puml
```

### **Option 4: IntelliJ IDEA Plugin**

1. Install **PlantUML integration** plugin
2. Open any `.puml` file
3. View diagram in preview pane
4. Right-click → "Save Diagram" to export

---

## 📋 Diagram Descriptions

### **1. Class Diagram** (`class_diagram.puml`)

**Shows:**
- Database tables (schools, users, buses, students, parents, etc.)
- Service classes (AuthService, SchoolService, ParentService, etc.)
- UI screens (LoginScreen, SchoolAdminApp, ParentHomeScreen, etc.)
- Relationships between all components

**Use for:**
- Understanding system architecture
- Database schema visualization
- Service layer structure
- Component relationships

---

### **2. Object Diagram** (`object_diagram.puml`)

**Shows:**
- Example instances of database records
- Real data examples (Kathmandu High School, buses, students)
- Actual relationships between objects

**Use for:**
- Understanding data flow with real examples
- Seeing how objects relate in practice
- Database record examples

---

### **3. State Diagram** (`state_diagram.puml`)

**Shows:**
- Student boarding status states
- Transitions between states (NotBoarded → Approaching → Boarded → Dropped)
- Conditions for state changes

**Use for:**
- Understanding student status lifecycle
- Notification trigger points
- Status transition logic

---

### **4. Sequence Diagram** (`sequence_diagram.puml`)

**Shows:**
- Parent tracking bus location flow
- Real-time location updates
- Parent editing bus stop location
- Interactions between components over time

**Use for:**
- Understanding feature workflows
- API call sequences
- Real-time communication flow
- User interaction patterns

---

### **5. Activity Diagram** (`activity_diagram.puml`)

**Shows:**
- Bus driver's daily workflow
- Student pickup and drop-off process
- Notification sending process
- Decision points and loops

**Use for:**
- Understanding business processes
- Driver workflow
- System behavior during operations

---

### **6. Component Diagram** (`component_diagram.puml`)

**Shows:**
- System components (panels, services, database)
- Component relationships
- Authentication flow
- Service dependencies
- External integrations

**Use for:**
- Understanding system architecture
- Component interactions
- Service layer structure
- Integration points

---

### **7. Deployment Diagram** (`deployment_diagram.puml`)

**Shows:**
- Physical deployment architecture
- Client devices (web, mobile)
- Flutter framework layers
- Supabase cloud infrastructure
- External APIs
- Communication protocols (HTTPS, WebSocket)

**Use for:**
- Understanding deployment architecture
- Infrastructure setup
- Technology stack
- Network communication

---

## 🎯 Quick Reference

| Diagram Type | Purpose | Best For |
|--------------|---------|----------|
| **Class** | System structure | Architecture, Database schema |
| **Object** | Data instances | Example data, Relationships |
| **State** | Status lifecycle | Student boarding states |
| **Sequence** | Time-based flow | Feature workflows, API calls |
| **Activity** | Process flow | Business processes, User actions |
| **Component** | Component structure | System architecture, Services |
| **Deployment** | Physical architecture | Infrastructure, Deployment |

---

## 🖼️ Export Formats

PlantUML supports multiple export formats:

- **PNG** - Best for documents, presentations
- **SVG** - Best for web, scalable graphics
- **PDF** - Best for printing, reports
- **EPS** - Best for LaTeX documents
- **ASCII Art** - Best for text-only environments

---

## 💡 Tips

1. **For presentations:** Export as PNG or SVG
2. **For documentation:** Export as PNG or PDF
3. **For web:** Use SVG for best quality
4. **For editing:** Keep the `.puml` source files

---

## 🔄 Updating Diagrams

To update any diagram:

1. Open the `.puml` file in a text editor
2. Modify the PlantUML code
3. Regenerate the diagram
4. Export in your preferred format

---

## 📚 PlantUML Syntax Reference

- **Class Diagram:** https://plantuml.com/class-diagram
- **Object Diagram:** https://plantuml.com/object-diagram
- **State Diagram:** https://plantuml.com/state-diagram
- **Sequence Diagram:** https://plantuml.com/sequence-diagram
- **Activity Diagram:** https://plantuml.com/activity-diagram-beta

---

## ✅ Diagram Checklist

- [x] All diagrams use orthogonal (straight) lines
- [x] Clear and not overly complex
- [x] Color-coded for easy identification
- [x] Proper labels and descriptions
- [x] Consistent styling across all diagrams

---

**Created:** November 6, 2025
**System:** Student Transport Monitoring System
**Format:** PlantUML (.puml)
