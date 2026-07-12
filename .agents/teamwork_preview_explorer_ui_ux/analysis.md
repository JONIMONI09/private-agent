# UI/UX & Rendering Audit Report

This report presents findings from a read-only investigation of the user interface, rendering layout, theme consistency, and user experience flows for the PrivateAgent application. The files audited are:
* `lib/screens/home_screen.dart`
* `lib/screens/settings_screen.dart`
* `lib/widgets/plan_view.dart`
* `lib/widgets/message_bubble.dart`

---

## Summary of Core Findings
1. **Critical Horizontal Layout Overflows:** In `settings_screen.dart`, text labels in the system permission and accessibility cards lack constraints and will overflow horizontally on standard mobile screens.
2. **App Bar Action Clutter:** In `home_screen.dart`, the app bar renders up to five actions simultaneously, causing layout collisions and title truncation on portrait mobile screens.
3. **Timeline Line Overrun:** In `plan_view.dart`, applying the bottom margin on the content card instead of the timeline row container causes the vertical connector line to overrun the card's bottom edge.
4. **TabBar Truncation:** In `settings_screen.dart`, a scrollable TabBar is configured as non-scrollable, resulting in crammed tabs and cut-off text labels.
5. **Dynamic Timeline Animation Glitches:** In `plan_view.dart`, wrapping layout elements inside `IntrinsicHeight` with dynamic transition animations causes rendering lag and layout calculation jumps.

---

## Detailed Findings & Proposed Replacements

### 1. lib/screens/home_screen.dart

#### Issue A: AppBar Actions Overflow
* **File & Lines:** `lib/screens/home_screen.dart`, lines 529-625
* **Problem:** There are up to five action buttons in the `AppBar` (visibility test, Shizuku link icon, compress button, delete button, settings button). On standard portrait screen widths (e.g., 360dp), this area takes up ~216dp, leaving insufficient space for the title and navigation elements, leading to overlapping, truncation, or layout exceptions.
* **Suggested Fix:** Group secondary actions ("Test screen reading", "Compress Context", and "Clear chat") into a `PopupMenuButton` (overflow menu) to reduce visual clutter and prevent layout crashes.
* **Suggested Replacement:**
  * **Before:**
    ```dart
    // Lines 529-625
    actions: [
      // Screen control test button
      IconButton(
        icon: const Icon(Icons.visibility),
        tooltip: 'Test screen reading',
        onPressed: () async {
          final isRunning = await _actionHandler.screenAutomation
              .isServiceRunning();
          if (!isRunning) {
            setState(() {
              _messages.add(ChatMessage(
                role: 'assistant',
                content:
                    '❌ Screen Control is not enabled!\n\n'
                    'To enable it:\n'
                    '1. Go to Settings (⚙️ icon)\n'
                    '2. Find "Screen Control (Accessibility)"\n'
                    '3. Tap "Open Accessibility Settings"\n'
                    '4. Find "PrivateAgent Screen Control"\n'
                    '5. Toggle it ON',
              ));
            });
            _scrollToBottom();
            return;
          }
          setState(() {
            _messages.add(ChatMessage(
              role: 'assistant',
              content: '🔍 Reading screen...',
            ));
          });
          _scrollToBottom();
          final description = await _actionHandler.screenAutomation
              .getScreenDescription();
          setState(() {
            _messages.add(ChatMessage(
              role: 'assistant',
              content: '📱 Screen Content:\n\n$description',
            ));
          });
          _scrollToBottom();
        },
      ),
      // Shizuku status indicator
      if (_actionHandler.shizuku.isAvailable)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            Icons.link,
            size: 18,
            color: _actionHandler.shizuku.hasPermission
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      IconButton(
        icon: _isCompressing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.compress),
        tooltip: 'Compress Context',
        onPressed: _isCompressing ? null : _compressContext,
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Clear chat',
        onPressed: () {
          setState(() {
            _messages.clear();
            _aiService.clearHistory();
            _currentPlan = null;
          });
        },
      ),
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen(
                aiService: _aiService,
                shizukuService: _actionHandler.shizuku,
                screenAutomationService: _actionHandler.screenAutomation,
                telegramService: _telegramService,
              ),
            ),
          );
          // Refresh Shizuku status after settings
          await _actionHandler.shizuku.checkAvailability();
          if (mounted) setState(() {});
        },
      ),
    ],
    ```
  * **After:**
    ```dart
    actions: [
      // Shizuku status indicator
      if (_actionHandler.shizuku.isAvailable)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.link,
            size: 18,
            color: _actionHandler.shizuku.hasPermission
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen(
                aiService: _aiService,
                shizukuService: _actionHandler.shizuku,
                screenAutomationService: _actionHandler.screenAutomation,
                telegramService: _telegramService,
              ),
            ),
          );
          // Refresh Shizuku status after settings
          await _actionHandler.shizuku.checkAvailability();
          if (mounted) setState(() {});
        },
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) async {
          switch (value) {
            case 'test_screen':
              final isRunning = await _actionHandler.screenAutomation.isServiceRunning();
              if (!isRunning) {
                setState(() {
                  _messages.add(ChatMessage(
                    role: 'assistant',
                    content:
                        '❌ Screen Control is not enabled!\n\n'
                        'To enable it:\n'
                        '1. Go to Settings (⚙️ icon)\n'
                        '2. Find "Screen Control (Accessibility)"\n'
                        '3. Tap "Open Accessibility Settings"\n'
                        '4. Find "PrivateAgent Screen Control"\n'
                        '5. Toggle it ON',
                  ));
                });
                _scrollToBottom();
                return;
              }
              setState(() {
                _messages.add(ChatMessage(
                  role: 'assistant',
                  content: '🔍 Reading screen...',
                ));
              });
              _scrollToBottom();
              final description = await _actionHandler.screenAutomation.getScreenDescription();
              setState(() {
                _messages.add(ChatMessage(
                  role: 'assistant',
                  content: '📱 Screen Content:\n\n$description',
                ));
              });
              _scrollToBottom();
              break;
            case 'compress':
              if (!_isCompressing) {
                await _compressContext();
              }
              break;
            case 'clear':
              setState(() {
                _messages.clear();
                _aiService.clearHistory();
                _currentPlan = null;
              });
              break;
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'test_screen',
            child: Row(
              children: [
                Icon(Icons.visibility),
                SizedBox(width: 8),
                Text('Test Screen Reading'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'compress',
            enabled: !_isCompressing,
            child: Row(
              children: [
                _isCompressing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.compress),
                const SizedBox(width: 8),
                const Text('Compress Context'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'clear',
            child: Row(
              children: [
                Icon(Icons.delete_outline),
                SizedBox(width: 8),
                Text('Clear Chat'),
              ],
            ),
          ),
        ],
      ),
    ],
    ```

---

### 2. lib/screens/settings_screen.dart

#### Issue A: TabBar Horizontal Compression
* **File & Lines:** `lib/screens/settings_screen.dart`, lines 211-218
* **Problem:** The `TabBar` is configured with 4 tabs, each including both an icon and text. Because `isScrollable` is left at the default (`false`), the system squeezes all 4 tabs into the screen width. Text labels (especially "Permissions" and "AI Models") will overlap, wrap awkwardly, or get cut off on portrait viewports.
* **Suggested Fix:** Enable `isScrollable: true` and configure `tabAlignment: TabAlignment.start` for standard scrollable Material 3 tab behavior.
* **Suggested Replacement:**
  * **Before:**
    ```dart
    bottom: const TabBar(
      tabs: [
        Tab(icon: Icon(Icons.tune), text: 'General'),
        Tab(icon: Icon(Icons.smart_toy), text: 'AI Models'),
        Tab(icon: Icon(Icons.security), text: 'Permissions'),
        Tab(icon: Icon(Icons.science), text: 'Advanced'),
      ],
    ),
    ```
  * **After:**
    ```dart
    bottom: const TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(icon: Icon(Icons.tune), text: 'General'),
        Tab(icon: Icon(Icons.smart_toy), text: 'AI Models'),
        Tab(icon: Icon(Icons.security), text: 'Permissions'),
        Tab(icon: Icon(Icons.science), text: 'Advanced'),
      ],
    ),
    ```

#### Issue B: Double/Redundant Dividers
* **File & Lines:** `lib/screens/settings_screen.dart`, lines 315-317
* **Problem:** Two consecutive divider widgets are specified back-to-back with an empty line in between, causing a redundant visual separator rendering on the General tab.
* **Suggested Fix:** Remove the duplicate divider.
* **Suggested Replacement:**
  * **Before:**
    ```dart
    const Divider(height: 32),

    const Divider(height: 32),
    ```
  * **After:**
    ```dart
    const Divider(height: 32),
    ```

#### Issue C: Shizuku Card Text Layout Overflow
* **File & Lines:** `lib/screens/settings_screen.dart`, lines 885-891
* **Problem:** Inside the card's row layout, a text widget with a relatively long string (`'Permission granted — ADB commands available'`) is placed adjacent to an icon. Because it lacks a wrapping constraint like `Expanded` or `Flexible`, it forces layout width expansion beyond boundaries, creating a horizontal rendering overflow.
* **Suggested Fix:** Wrap the text widget in an `Expanded` widget to force proper line wrapping.
* **Suggested Replacement:**
  * **Before:**
    ```dart
    Row(
      children: [
        Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          'Permission granted — ADB commands available',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 13,
          ),
        ),
      ],
    ),
    ```
  * **After:**
    ```dart
    Row(
      children: [
        Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
          size: 16,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Permission granted — ADB commands available',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
    ```

#### Issue D: Accessibility Card Text Layout Overflow
* **File & Lines:** `lib/screens/settings_screen.dart`, lines 960-966
* **Problem:** Similar to Issue C, a long descriptive string (`'Can read screen, tap, scroll, and type in other apps'`) is placed directly inside a `Row` alongside an icon. It lacks boundaries and will result in a visual layout overflow on most mobile device dimensions.
* **Suggested Fix:** Wrap the text widget in an `Expanded` widget.
* **Suggested Replacement:**
  * **Before:**
    ```dart
    Row(
      children: [
        Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          'Can read screen, tap, scroll, and type in other apps',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 13,
          ),
        ),
      ],
    ),
    ```
  * **After:**
    ```dart
    Row(
      children: [
        Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
          size: 16,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Can read screen, tap, scroll, and type in other apps',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
    ```

---

### 3. lib/widgets/plan_view.dart

#### Issue A: Timeline Line Visual Overrun
* **File & Lines:** `lib/widgets/plan_view.dart`, line 136-139, line 188
* **Problem:** In `_buildStepItem()`, a bottom margin of `12` is defined inside the content card container (representing the right column), whereas the timeline container (left column) has no bottom margin. As the columns are wrapped inside `IntrinsicHeight`, the row expands to fit the content container including its outer margin. This causes the vertical timeline connector line in the left column to extend `12dp` further down, running past the bottom of the card's rounded border and causing a bad visual alignment.
* **Suggested Fix:** Apply the bottom margin to the entire row container `AnimatedContainer` instead of the inner content card `AnimatedContainer`, ensuring proper layout alignment.
* **Suggested Replacement:**
  * **Before:**
    ```dart
    // Line 136-139
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      child: IntrinsicHeight(
        child: Row(
    
    // ...
    
    // Line 188
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
    ```
  * **After:**
    ```dart
    // Apply margin to outer container (Line 136)
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(

    // ...
    
    // Remove margin from inner container (Line 188)
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
    ```

#### Issue B: Button Label Layout Overflow on Compact Screen Sizes
* **File & Lines:** `lib/widgets/plan_view.dart`, lines 462-533
* **Problem:** The action buttons (Cancel, Edit, Proceed) are rendered horizontally in a `Row`. On narrow screens, the localized labels ("Running...", "Proceed", "Cancel") combined with button icons and interior margins can exceed available horizontal screen dimensions, causing a horizontal layout overflow exception.
* **Suggested Fix:** Use `FittedBox` on labels to scale down text size dynamically under tight constraints.
* **Suggested Replacement:**
  * **Before:**
    ```dart
    // Cancel label (lines 467)
    label: const Text('Cancel'),
    
    // Edit label (line 486)
    label: const Text('Edit'),
    
    // Proceed label (line 521)
    label: Text(isExecuting ? 'Running...' : 'Proceed'),
    ```
  * **After:**
    ```dart
    // Cancel label (lines 467)
    label: const FittedBox(
      fit: BoxFit.scaleDown,
      child: Text('Cancel'),
    ),
    
    // Edit label (line 486)
    label: const FittedBox(
      fit: BoxFit.scaleDown,
      child: Text('Edit'),
    ),
    
    // Proceed label (line 521)
    label: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(isExecuting ? 'Running...' : 'Proceed'),
    ),
    ```

---

### 4. lib/widgets/message_bubble.dart

#### Issue A: Action Result Badge Text Overflow
* **File & Lines:** `lib/widgets/message_bubble.dart`, lines 108-117
* **Problem:** In the message action badge, the action type text is rendered inside a `Row`. The `Row` is encapsulated within a container that restricts maximum width (`maxWidth: screenWidth * 0.8`). If the tool/action identifier is exceptionally long (e.g., `get_screen_automation_description_by_selector`), the text will try to render in a single horizontal line, overflow the `Row` constraints, and throw horizontal layout errors.
* **Suggested Fix:** Wrap the action type label in `Flexible` and specify `overflow: TextOverflow.ellipsis`.
* **Suggested Replacement:**
  * **Before:**
    ```dart
    Text(
      widget.message.actionResult!.actionType.replaceAll('_', ' '),
      style: TextStyle(
        fontSize: 11,
        color: widget.message.actionResult!.success
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
        fontWeight: FontWeight.w600,
      ),
    ),
    ```
  * **After:**
    ```dart
    Flexible(
      child: Text(
        widget.message.actionResult!.actionType.replaceAll('_', ' '),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: widget.message.actionResult!.success
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    ```
