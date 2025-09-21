# MarketsWidgetKit

## Introduction

This repository contains a collection of widgets built using WidgetKit for iOS 17. WidgetKit allows developers to create beautiful and informative widgets that can be added to the home screen.

<img width="400" height="870" alt="image" src="https://github.com/user-attachments/assets/0d2304e2-06f5-4f00-91f0-e3e6ee765c22" />
<img width="400" height="870" alt="large-screenshot" src="https://github.com/user-attachments/assets/3267e067-39ae-4763-b685-8ab7ee1471f9" />


## Getting Started

### Requirements

- iOS 17 or later
- Xcode 15 or later

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/edwinbosire/MarketsWidgetKit.git
   ```

2. Open the project in Xcode:
   ```bash
   cd MarketsWidgetKit
   open MarketsWidgetKit.xcodeproj
   ```

3. Build and run the project.

## Using WidgetKit

### Creating a Simple Widget

1. **Create a Widget Extension**: In Xcode, add a new target and select "Widget Extension".

2. **Define Your Widget**: In the `YourWidget.swift` file, define your widget's content, configuration, and timeline.

3. **Preview Your Widget**: Use the Xcode canvas to preview your widget in different sizes.

### Example Code

Here's a basic example of a widget that displays stock prices:

```swift
import WidgetKit
import SwiftUI

struct StockPriceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StockPriceWidget", provider: Provider()) { entry in
            StockPriceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Stock Price Widget")
        .description("Show the latest stock prices.")
    }
}
```

### Updating Your Widget

Widgets can be updated based on time or when specific data changes. Use the `TimelineProvider` to manage updates.

## Conclusion

With WidgetKit, creating widgets is straightforward and allows for a rich user experience on iOS 17. Explore the provided examples and customize them to fit your needs!
