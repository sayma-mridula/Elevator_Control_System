# 🚀 FPGA Smart Elevator Control System (Basys3)

## 📌 Project Overview

This project implements a **Smart Elevator Control System** using **Verilog HDL** on the **Basys3 FPGA (Artix-7)**.
The system simulates a real-world elevator with multiple passengers, fare calculation, and efficient movement using a sweep-based algorithm.

---

## 🎯 Features

* 🏢 Supports **8 floors (0–7)**
* 👥 Handles up to **4 passengers simultaneously**
* 🔄 **Sweep-based FSM** (efficient real-world elevator behavior)
* 💰 **Automatic fare calculation** (5 taka per floor)
* ⏱️ Real-time operation using **100 MHz clock**
* 🔢 **7-segment display** for:

  * Passenger count
  * Current floor
  * Fare
  * Completion status ("EE")
* 🔘 **Debounced button inputs**
* 💡 Status LEDs:

  * UP direction
  * DOWN direction
  * Memory FULL indicator

---

## 🧠 System Architecture

The system is modular and consists of:

* **Control Unit (FSM)** – Core logic controlling elevator behavior
* **Passenger Memory** – Stores up to 4 passengers
* **ALU** – Calculates fare using `|dest - start|`
* **Clock Divider** – Generates 2 Hz and 1 kHz signals
* **Button Edge Detector** – Debouncing + edge detection
* **7-Segment Display Driver** – Output visualization
* **Top Module** – Integrates all components

---

## ⚙️ How It Works

1. User selects:

   * Start floor (SW[5:3])
   * Destination floor (SW[2:0])
2. Press **Add Button (BTNC)** to store passenger
3. Press **Start Button (BTNU)** to begin elevator operation
4. Elevator:

   * Picks up passengers
   * Moves floor-by-floor (2 Hz)
   * Drops passengers at destination
5. Fare is displayed
6. User enters payment (SW[15:10]) and confirms (BTND)
7. After all passengers → displays **"EE"**

---

## 📂 Project Structure

```
├── elevator_top.v
├── control_unit.v
├── memory_unit.v
├── alu.v
├── clk_divider.v
├── btn_edge.v
├── seven_segment.v
├── Basys3_Elevator.xdc
├── Elevator_Control_System.pdf
```

---

## 🧪 Test Cases

* ✅ Passenger addition
* ✅ Full memory handling
* ✅ Same-floor rejection
* ✅ Multi-passenger sweep
* ✅ Correct fare calculation
* ✅ Payment validation
* ✅ Direction control (UP/DOWN)

---

## 🛠️ Tools & Technologies

* Verilog HDL
* Xilinx Vivado
* Basys3 FPGA (Artix-7)

---

## 📊 Results

* ✔️ Successfully implemented on hardware
* ✔️ All test cases passed
* ✔️ Timing closure achieved at 100 MHz
* ✔️ Very low FPGA resource usage

---

## 🚧 Limitations

* Supports only 8 floors
* Maximum 4 passengers
* No persistent memory (resets on restart)

---

## 🔮 Future Improvements

* Increase floor range (16/32 floors)
* Expand passenger capacity
* Smart scheduling optimization
* UART logging for real-time monitoring
* Dynamic fare system

---

## 👨‍💻 Author

**Sayma Mushsharat**
CSE, KUET

---

## 📜 License

This project is for academic and educational purposes.
