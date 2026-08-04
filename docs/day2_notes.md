# Day 2 Master Notes: Dart Programming Fundamentals (Revised)

Welcome to Day 2 of your training! This document is a comprehensive guide to the Dart programming language, specifically focused on the concepts you will need to build **BlindChess**. It utilizes modern Dart 3.x concepts (such as Sound Null Safety, Pattern Matching, Switch Expressions, and Records).

---

## 1. Variables

### Explanation
Variables are containers that store data in computer memory. Dart is a strongly-typed, type-safe language, meaning it enforces strict variable types. However, Dart supports **Type Inference** (automatically figuring out the variable type based on the value assigned to it).

* **`var`**: Declares a variable whose value can be reassigned later. The type is locked once inferred.
* **`final`**: Declares a read-only variable whose value is determined at runtime but cannot change once set.
* **`const`**: Declares a compile-time constant. Its value must be known before the program runs and is deeply immutable.
* **Explicit Types**: Declaring variables with their exact types (e.g., `int`, `String`) instead of using `var` to improve code readability and self-documentation.

### Syntax
```dart
var variableName = value;
final type variableName = value;
const type variableName = value;
Type variableName = value;
```

### Examples
#### Normal Examples
1. **Using `var` (Type Inference):**
   ```dart
   var score = 100; // Inferenced as int. You cannot later assign a String to 'score'.
   score = 150;     // Allowed: reassignable
   ```
2. **Using `final` and `const`:**
   ```dart
   final currentTime = DateTime.now(); // Resolved at runtime (current system time)
   const maxScoreAllowed = 9999;       // Checked at compile time (hardcoded constant)
   ```

#### BlindChess Example
```dart
const int totalSquares = 64;           // Chessboard dimension is a compile-time constant
final String gameId = "game_xyz123";   // Resolved dynamically when the game starts
var currentTurnColor = "white";        // Reassigned as game progresses ("white" <-> "black")
```

---

## 2. Data Types

### Explanation
Dart has built-in support for standard data types:
* **`int`**: Integer values (64-bit precision, e.g., `1`, `-42`).
* **`double`**: 64-bit double-precision floating-point numbers (e.g., `3.14`, `-0.5`).
* **`String`**: UTF-16 character sequences. Supports single, double, and triple quotes (for multi-line strings).
* **`bool`**: Boolean values (`true` or `false`).
* **`dynamic`**: Special escape hatch type that disables type checking. The variable can hold any type and can change type at runtime. (Use only when necessary).
* **`Object`**: The base class for all non-nullable Dart objects.
* **`Object?`**: The root of the Dart class hierarchy, allowing any value (including `null`).

### Syntax
```dart
int number = 10;
double decimal = 10.5;
String text = "hello";
bool flag = true;
dynamic variable = "text";
Object someObj = 42;
Object? nullableObj = null;
```

### Examples
#### Normal Examples
1. **Numbers and String interpolation:**
   ```dart
   int age = 25;
   double price = 19.99;
   String message = "Age: $age, Price: \$$price"; // Escape $ using backslash
   ```
2. **Using Dynamic vs Object:**
   ```dart
   dynamic val = "String value";
   val = 42; // Completely fine, type changes dynamically.
   
   Object objVal = "String value";
   // objVal = 42; // Allowed, but the compiler does not let you call methods that aren't on Object.
   ```

#### BlindChess Example
```dart
int halfMovesCount = 0;              // Move counter for 50-move draw rule
double timeRemainingSeconds = 600.0; // Player game clock timer
String playerPrompt = "White's turn"; // Status announcement string
bool isCheckmate = false;            // Game state flag
```

---

## 3. Null Safety

### Explanation
Dart uses **Sound Null Safety**. Variables cannot contain `null` unless explicitly marked.
* **`?`**: Marks a type as nullable (e.g., `int?`).
* **`!`**: Assertion operator. Force-casts a nullable value to non-nullable (throws a runtime error if null).
* **`??`**: Null-coalescing operator. Returns the right-hand value if the left-hand value is null.
* **`??=`**: Null-aware assignment. Assigns a value only if the variable is currently null.
* **`required`**: Declares that a named parameter must be provided by the caller.

### Syntax
```dart
Type? variableName; // Nullable
variableName ?? defaultValue;
variableName ??= newValue;
```

### Examples
#### Normal Examples
1. **Handling Nullable Variables:**
   ```dart
   String? middleName;
   String displayName = middleName ?? "None"; // fallback to "None"
   ```
2. **Null-aware assignment (`??=`):**
   ```dart
   int? highscore;
   highscore ??= 100; // assigns 100 because highscore was null
   ```

#### BlindChess Example
```dart
String? selectedSquare; // Null if no square is clicked/selected
String activeSquare = selectedSquare ?? "none"; // Fallback to "none" if null
```

---

## 4. Operators

### Explanation
Operators are symbols that perform operations on values (operands).
* **Arithmetic**: `+`, `-`, `*`, `/`, `%` (modulo), `~/` (integer division).
* **Comparison**: `==` (equal), `!=` (not equal), `>`, `<`, `>=`, `<=`.
* **Logical**: `&&` (AND), `||` (OR), `!` (NOT).
* **Assignment**: `=`, `+=`, `-=`, `*=`, `/=`.
* **Ternary**: `condition ? expr1 : expr2` (Inline if-else).

### Syntax
```dart
var result = a + b;
bool isTrue = (a == b) && (c > d);
var output = condition ? valueIfTrue : valueIfFalse;
```

### Examples
#### Normal Examples
1. **Arithmetic & Integer Division:**
   ```dart
   int total = 5 + 3 * 2; // 11 (standard operator precedence)
   int intDiv = 10 ~/ 3;  // 3 (integer division, returns integer)
   ```
2. **Ternary Operator:**
   ```dart
   int score = 85;
   String grade = score >= 50 ? "Pass" : "Fail";
   ```

#### BlindChess Example
```dart
int moveIndex = 3;
String sideToMove = (moveIndex % 2 == 0) ? "white" : "black"; 
```

---

## 5. Functions

### Explanation
Functions are blocks of reusable code.
* **Normal functions**: Traditional block functions containing return statements.
* **Arrow functions**: Shorthand for single-line expressions.
* **Optional positional parameters**: Enclosed in `[]`, they do not require parameter names.
* **Named parameters**: Enclosed in `{}`, referenced by name, and can be marked `required`.

### Syntax
```dart
ReturnType functionName(ParameterType param) {
  return value;
}
ReturnType arrowFunction() => value;
void namedParams({required String first, String? optional}) {}
```

### Examples
#### Normal Examples
1. **Arrow & Named Parameters:**
   ```dart
   int doubleValue(int x) => x * 2;
   
   void greet({required String name, String greeting = "Hello"}) {
     print("$greeting, $name!");
   }
   ```
2. **Optional Positional Parameters:**
   ```dart
   String makeTitle(String first, [String? last]) {
     return last != null ? "$first $last" : first;
   }
   ```

#### BlindChess Example
```dart
// Checks if coordinates are within standard chess bounds (0-7)
bool isWithinBoard({required int row, required int col}) {
  return row >= 0 && row < 8 && col >= 0 && col < 8;
}
```

---

## 6. Collections

### Explanation
Collections group multiple items together.
* **`List`**: An ordered collection of items, allowing duplicates (0-indexed).
* **`Set`**: An unordered collection of unique items (no duplicates).
* **`Map`**: A collection of key-value pairs. Keys must be unique.

### Syntax
```dart
List<Type> listName = [item1, item2];
Set<Type> setName = {item1, item2};
Map<KeyType, ValueType> mapName = {key1: value1};
```

### Examples
#### Normal Examples
1. **Lists & Sets:**
   ```dart
   List<String> fruits = ["apple", "banana", "apple"]; // Allows duplicates
   Set<String> uniqueFruits = {"apple", "banana", "apple"}; // "apple" stored once
   ```
2. **Maps:**
   ```dart
   Map<String, int> phoneBook = {
     "Alice": 123456,
     "Bob": 789012
   };
   ```

#### BlindChess Example
```dart
List<String> moveHistory = ["e4", "e5", "Nf3"];
Set<String> occupiedSquares = {"e4", "e5", "f3"};
Map<String, String> piecePlacement = {
  "e1": "White King",
  "e8": "Black King",
};
```

---

## 7. Loops

### Explanation
Loops repeat a block of code until a condition is met.
* **`for`**: Traditional loop using index pointers.
* **`for-in`**: Iterates directly through elements of a collection.
* **`while`**: Repeats while a condition evaluates to true. Checks condition *before* execution.
* **`do-while`**: Execution occurs once *before* checking the exit condition.

### Syntax
```dart
for (var i = 0; i < limit; i++) {}
for (var item in collection) {}
while (condition) {}
do {} while (condition);
```

### Examples
#### Normal Examples
1. **For and For-in Loops:**
   ```dart
   for (int i = 0; i < 3; i++) {
     print(i);
   }
   List<String> names = ["Alice", "Bob"];
   for (var name in names) {
     print(name);
   }
   ```
2. **While Loops:**
   ```dart
   int countdown = 3;
   while (countdown > 0) {
     print(countdown--);
   }
   ```

#### BlindChess Example
```dart
// Iterate over all squares to initialize a chess row
List<String> rowSquares = [];
for (int col = 0; col < 8; col++) {
  rowSquares.add("Square $col");
}
```

---

## 8. Decision Making & Switch Expressions (Dart 3.x)

### Explanation
Decision-making structures direct execution based on conditions.
* **`if` / `else if` / `else`**: Evaluates boolean conditions.
* **`switch` (Traditional)**: Matches values against several distinct `case` blocks.
* **`switch` Expressions (Dart 3.x)**: A compact way to assign a value based on a switch match. Returns a value directly and is exhaustive (must handle all cases).

### Syntax
```dart
// Traditional If-Else
if (condition) {} else {}

// Dart 3.x Switch Expression
var result = switch (value) {
  case1 => value1,
  case2 => value2,
  _ => defaultValue, // Default wildcard fallback
};
```

### Examples
#### Normal Examples
1. **If-Else logic:**
   ```dart
   int score = 80;
   if (score >= 70) {
     print("Pass");
   } else {
     print("Fail");
   }
   ```
2. **Switch Expression (Dart 3.x):**
   ```dart
   String status = "pending";
   String description = switch (status) {
     "pending" => "Waiting...",
     "completed" => "Done!",
     _ => "Unknown"
   };
   ```

#### BlindChess Example
```dart
enum PieceType { pawn, knight, bishop, rook, queen, king }

// Get character abbreviation of a piece using switch expression
String getPieceSymbol(PieceType type) => switch (type) {
  PieceType.pawn => "P",
  PieceType.knight => "N",
  PieceType.bishop => "B",
  PieceType.rook => "R",
  PieceType.queen => "Q",
  PieceType.king => "K",
};
```

---

## 9. Classes

### Explanation
A **Class** is a blueprint/template used to create objects. An **Object** is an instance of a class.
* **Constructor**: A special method used to initialize a new instance.
* **Named Constructor**: Provides alternative initialization configurations for a class.
* **`this`**: Keyword referencing the current object instance.

### Syntax
```dart
class ClassName {
  Type field;
  
  // Default Constructor
  ClassName(this.field);
  
  // Named Constructor
  ClassName.named() : field = defaultValue;
}
```

### Examples
#### Normal Examples
1. **Defining and Instantiating Classes:**
   ```dart
   class Point {
     double x, y;
     Point(this.x, this.y);
     Point.origin() : x = 0, y = 0;
   }
   
   Point p1 = Point(2.0, 3.0);
   Point origin = Point.origin();
   ```

#### BlindChess Example
```dart
class Position {
  final int file; // column (0-7)
  final int rank; // row (0-7)

  // Default constructor with named required parameters
  Position({required this.file, required this.rank});

  // Named constructor parsing chess coordinates like "e4"
  Position.fromAlgebraic(String coord)
      : file = coord.codeUnitAt(0) - 'a'.codeUnitAt(0),
        rank = int.parse(coord[1]) - 1;
}
```

---

## 10. Enums

### Explanation
An **Enum** (Enumerated Type) is a special class representing a fixed set of constant values. In Dart 3.x, enums can have fields, constructors, and methods.

### Syntax
```dart
enum EnumName { value1, value2, value3 }
```

### Examples
#### Normal Examples
1. **Simple Enum and Switch:**
   ```dart
   enum NetworkState { disconnected, connecting, connected }
   
   NetworkState state = NetworkState.connected;
   if (state == NetworkState.connected) {
     print("Online");
   }
   ```

#### BlindChess Example
```dart
enum ChessColor { white, black }

// Enhanced Enum with values
enum PieceValue {
  pawn(1),
  knight(3),
  bishop(3),
  rook(5),
  queen(9),
  king(1000);

  final int points;
  const PieceValue(this.points); // Enhanced enum constructor
}
```

---

## 11. Basic OOP (Object-Oriented Programming)

### Explanation
* **Encapsulation**: Hiding internal data details by making class members private (using an underscore `_`) and exposing them only via public getters/setters.
* **Inheritance**: Allowing a child class to inherit fields and methods from a parent class using the `extends` keyword.
* **Polymorphism**: The ability for different subclasses to provide custom implementations of the same inherited method.

### Syntax
```dart
class Parent {}
class Child extends Parent {}
```

### Examples
#### Normal Examples
1. **Inheritance & Polymorphism:**
   ```dart
   class Animal {
     void makeSound() => print("Generic noise");
   }
   
   class Dog extends Animal {
     @override
     void makeSound() => print("Bark"); // Polymorphism
   }
   ```
2. **Encapsulation with Getters:**
   ```dart
   class BankAccount {
     double _balance = 0.0; // Private field
     
     double get balance => _balance; // Read-only access
   }
   ```

#### BlindChess Example
```dart
// Base Chess Piece class (Inheritance blueprint)
abstract class ChessPiece {
  final ChessColor color;
  ChessPiece(this.color);

  // Polymorphic method: every subclass must specify its own rules
  bool isValidMove(Position from, Position to);
}

// Inherits from ChessPiece
class Knight extends ChessPiece {
  Knight(super.color);

  @override
  bool isValidMove(Position from, Position to) {
    int diffFile = (from.file - to.file).abs();
    int diffRank = (from.rank - to.rank).abs();
    return (diffFile == 1 && diffRank == 2) || (diffFile == 2 && diffRank == 1);
  }
}
```

---

## Common Mistakes

1. **Reassigning a `final` or `const` variable:**
   ```dart
   final name = "White King";
   // name = "Black King"; // ERROR: final variables can only be set once.
   ```
2. **Missing checks on nullable fields:**
   ```dart
   String? file;
   // int length = file.length; // ERROR: property access must use null safety
   int length = file?.length ?? 0; // CORRECT
   ```
3. **Modifying a collection while iterating through it:**
   Modifying a collection directly inside a `for-in` loop throws a concurrent modification error. Filter the collection or use classic decrementing index loops instead.

---

## Best Practices

* **Always specify generic types for collections:** Write `List<String>` instead of raw `List` to preserve type safety.
* **Keep classes encapsulated:** Avoid exposing variables directly if they shouldn't be changed. Mark them private (`_variableName`) and expose a getter where necessary.
* **Prefer arrow syntax `=>` for short, single-expression methods:** It makes code cleaner and easier to scan.
* **Utilize constant constructors:** Write `const MyWidget()` whenever possible to reduce garbage collection load.

---

## Summary
Today we explored the fundamentals of Dart:
* Variables store data using inference (`var`), runtime constraints (`final`), and compile-time constants (`const`).
* Types and Null Safety protect the runtime application from common pointer crashes.
* Collection objects (Lists, Sets, Maps) handle structural data records.
* Classes, Enums, and OOP structures create cohesive models for elements like Pieces, Colors, and Coordinates.

---

## Day 2 Exercises

Write the answers in a scratch file or practice sheet. Do not modify application files.

1. **Variables:** Declare a variable `boardSize` that cannot be changed after compilation and set it to `8`.
2. **Types:** Define a double representation of a percentage value of `0.75` and call it `winRatio`.
3. **Null Safety:** Fix this line: `String text = null;` using Dart null safety.
4. **Ternary Operator:** Write an inline condition that assigns `"Check!"` to `status` if a boolean `isCheck` is true, otherwise assign `"Safe"`.
5. **Arrow Functions:** Convert this block to a single-line arrow function:
   ```dart
   int doubleCount(int x) {
     return x * 2;
   }
   ```
6. **Collections (Lists):** Create a list containing the names of the 8 columns of a chessboard (`"a"` through `"h"`).
7. **Collections (Maps):** Write a key-value Map associating three pieces with their standard values: Pawn (1), Knight (3), and Queen (9).
8. **Switch Statements:** Write a switch block matching an enum `PieceType` that prints the name of the piece.
9. **Classes:** Write a class named `Move` with two required fields: `String from` and `String to`.
10. **Enums:** Declare an enum naming the two phases of a chess game: `opening` and `endgame`.
