      ******************************************************************
      * Author: Kaung Myat Htun
      * Date: 2025-07-18
      * Purpose: Daily Summary Report - Check-ins, Check-outs,
      *          Occupancy Rate, and Revenue
      * Tectonics: cobc
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. dailySummaryReport.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT BOOKING-FILE ASSIGN TO '../DATA/BOOKINGS.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS BOOKING-ID.

           SELECT ROOMS-FILE ASSIGN TO '../DATA/ROOMS.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS ROOM-ID.

           SELECT INVOICES-FILE ASSIGN TO '../DATA/INVOICES.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS INVOICE-ID.

       DATA DIVISION.
       FILE SECTION.
       FD  BOOKING-FILE.
       COPY "./CopyBooks/BOOKINGS.cpy".

       FD  ROOMS-FILE.
       COPY "./CopyBooks/ROOMS.cpy".

       FD  INVOICES-FILE.
       COPY "./CopyBooks/INVOICES.cpy".

       WORKING-STORAGE SECTION.
       01  WS-BOOKING-FILE-STATUS  PIC 99.
       01  WS-ROOMS-FILE-STATUS    PIC 99.
       01  WS-INVOICE-FILE-STATUS  PIC 99.
       01  WS-EOF                  PIC X VALUE 'N'.

       01  WS-REPORT-DATE.
           05 WS-REPORT-YEAR       PIC 9(4).
           05 WS-REPORT-MONTH      PIC 9(2).
           05 WS-REPORT-DAY        PIC 9(2).
       01  WS-CHECKIN-DATE         PIC 9(8).
       01  WS-CHECKOUT-DATE        PIC 9(8).

       *> Counters
       01  WS-CHECKINS-TODAY       PIC 9(3) VALUE 0.
       01  WS-CHECKOUTS-TODAY      PIC 9(3) VALUE 0.
       01  WS-OCCUPIED-ROOMS       PIC 9(3) VALUE 0.
       01  WS-TOTAL-ROOMS          PIC 9(3) VALUE 0.
       01  WS-DAILY-REVENUE        PIC 9(9)V99 VALUE 0.

       *> Calculations
       01  WS-OCCUPANCY-RATE       PIC 9(3)V99.
       01  WS-OCCUPANCY-PERCENT    PIC 999V99.

       *> Display fields
       01  WS-DISPLAY-CHECKINS     PIC ZZ9.
       01  WS-DISPLAY-CHECKOUTS    PIC ZZ9.
       01  WS-DISPLAY-OCCUPIED     PIC ZZ9.
       01  WS-DISPLAY-TOTAL        PIC ZZ9.
       01  WS-DISPLAY-OCCUPANCY    PIC ZZ9.99.
       01  WS-DISPLAY-REVENUE      PIC $(9).

       *> Temporary fields
       01  WS-TOTAL-CHARGE-DEC     PIC 9(9)V99.
       01  WS-TARGET-BOOKING-ID    PIC 9(5).
       01  WS-INVOICE-FOUND        PIC X VALUE 'N'.

       LINKAGE SECTION.
       01 LINK PIC 9.

       PROCEDURE DIVISION USING LINK.
       MAIN-PROCEDURE.
           PERFORM GET-REPORT-DATE
           PERFORM COUNT-CHECKINS-CHECKOUTS
           PERFORM CALCULATE-OCCUPANCY
           PERFORM CALCULATE-DAILY-REVENUE
           PERFORM DISPLAY-SUMMARY-REPORT
           GOBACK.

       GET-REPORT-DATE.
           ACCEPT WS-REPORT-DATE FROM DATE YYYYMMDD.

       COUNT-CHECKINS-CHECKOUTS.
           OPEN INPUT BOOKING-FILE
           IF WS-BOOKING-FILE-STATUS NOT = 00
               DISPLAY "Error opening BOOKING file: "
                       WS-BOOKING-FILE-STATUS
               GOBACK
           END-IF

           MOVE 'N' TO WS-EOF
           MOVE 0 TO WS-CHECKINS-TODAY
           MOVE 0 TO WS-CHECKOUTS-TODAY

           PERFORM UNTIL WS-EOF = 'Y'
               READ BOOKING-FILE NEXT RECORD
               AT END
                   MOVE 'Y' TO WS-EOF
               NOT AT END
                   PERFORM CHECK-BOOKING-DATES
               END-READ
           END-PERFORM

           CLOSE BOOKING-FILE.

       CHECK-BOOKING-DATES.
           *> Convert dates to numeric for comparison
           MOVE CHECKIN-DATE TO WS-CHECKIN-DATE
           MOVE CHECKOUT-DATE TO WS-CHECKOUT-DATE

           *> Count check-ins today
           IF WS-CHECKIN-DATE = WS-REPORT-DATE AND
              CHEKIN-FLAG = 'Y'
               ADD 1 TO WS-CHECKINS-TODAY
           END-IF

           *> Count check-outs today
           IF WS-CHECKOUT-DATE = WS-REPORT-DATE AND
              CHECKOUT-FLAG = 'Y'
               ADD 1 TO WS-CHECKOUTS-TODAY
           END-IF.

       CALCULATE-OCCUPANCY.
           OPEN INPUT ROOMS-FILE
           IF WS-ROOMS-FILE-STATUS NOT = 00
               DISPLAY "Error opening ROOMS file: "
                       WS-ROOMS-FILE-STATUS
               GOBACK
           END-IF

           MOVE 'N' TO WS-EOF
           MOVE 0 TO WS-OCCUPIED-ROOMS
           MOVE 0 TO WS-TOTAL-ROOMS

           PERFORM UNTIL WS-EOF = 'Y'
               READ ROOMS-FILE NEXT RECORD
               AT END
                   MOVE 'Y' TO WS-EOF
               NOT AT END
                   ADD 1 TO WS-TOTAL-ROOMS
                   IF R-STATUS = "Occupied" OR R-STATUS = "Booked"
                       ADD 1 TO WS-OCCUPIED-ROOMS
                   END-IF
               END-READ
           END-PERFORM

           CLOSE ROOMS-FILE

           *> Calculate occupancy rate percentage
           IF WS-TOTAL-ROOMS > 0
               COMPUTE WS-OCCUPANCY-RATE =
                   (WS-OCCUPIED-ROOMS / WS-TOTAL-ROOMS) * 100
           ELSE
               MOVE 0 TO WS-OCCUPANCY-RATE
           END-IF.

       CALCULATE-DAILY-REVENUE.
           OPEN INPUT BOOKING-FILE
           IF WS-BOOKING-FILE-STATUS NOT = 00
               DISPLAY "Error opening BOOKING file for revenue"
               GOBACK
           END-IF

           OPEN INPUT INVOICES-FILE
           IF WS-INVOICE-FILE-STATUS NOT = 00
               DISPLAY "Error opening INVOICES file"
               CLOSE BOOKING-FILE
               GOBACK
           END-IF

           MOVE 'N' TO WS-EOF
           MOVE 0 TO WS-DAILY-REVENUE

           PERFORM UNTIL WS-EOF = 'Y'
               READ BOOKING-FILE NEXT RECORD
               AT END
                   MOVE 'Y' TO WS-EOF
               NOT AT END
                   PERFORM CHECK-DAILY-BOOKING-REVENUE
               END-READ
           END-PERFORM

           CLOSE BOOKING-FILE
           CLOSE INVOICES-FILE.

       CHECK-DAILY-BOOKING-REVENUE.
           *> Only process completed bookings
           IF BOOKING-STATUS = "Completed"
               MOVE CHECKIN-DATE TO WS-CHECKIN-DATE
               MOVE CHECKOUT-DATE TO WS-CHECKOUT-DATE

               *> Include revenue if guest was staying on report date
               IF WS-CHECKOUT-DATE = WS-REPORT-DATE
                   PERFORM GET-INVOICE-REVENUE
               END-IF
           END-IF.

       GET-INVOICE-REVENUE.
           MOVE BOOKING-ID TO WS-TARGET-BOOKING-ID
           PERFORM FIND-INVOICE-FOR-BOOKING
           IF WS-INVOICE-FOUND = 'Y'
               COMPUTE WS-DAILY-REVENUE = WS-DAILY-REVENUE +
               TOTAL-CHARGE
           END-IF.

       FIND-INVOICE-FOR-BOOKING.
           MOVE 'N' TO WS-INVOICE-FOUND

           *> Close and reopen invoices file for fresh search
           CLOSE INVOICES-FILE
           OPEN INPUT INVOICES-FILE

           IF WS-INVOICE-FILE-STATUS = 00
               MOVE 'N' TO WS-EOF
               PERFORM UNTIL WS-EOF = 'Y' OR WS-INVOICE-FOUND = 'Y'
                   READ INVOICES-FILE NEXT RECORD
                   AT END
                       MOVE 'Y' TO WS-EOF
                   NOT AT END
                       IF BOOKING-ID-IV = WS-TARGET-BOOKING-ID
                           MOVE 'Y' TO WS-INVOICE-FOUND
                       END-IF
                   END-READ
               END-PERFORM
           END-IF.

       DISPLAY-SUMMARY-REPORT.
           MOVE WS-CHECKINS-TODAY TO WS-DISPLAY-CHECKINS
           MOVE WS-CHECKOUTS-TODAY TO WS-DISPLAY-CHECKOUTS
           MOVE WS-OCCUPIED-ROOMS TO WS-DISPLAY-OCCUPIED
           MOVE WS-TOTAL-ROOMS TO WS-DISPLAY-TOTAL
           MOVE WS-OCCUPANCY-RATE TO WS-DISPLAY-OCCUPANCY
           MOVE WS-DAILY-REVENUE TO WS-DISPLAY-REVENUE

           DISPLAY " "
           DISPLAY "=========================================="
           DISPLAY "         DAILY SUMMARY REPORT"
           DISPLAY "=========================================="
           DISPLAY "Report Date: " WS-REPORT-YEAR "/"
                   WS-REPORT-MONTH "/" WS-REPORT-DAY
           DISPLAY " "
           DISPLAY "CHECK-IN/CHECK-OUT ACTIVITY:"
           DISPLAY "  Check-ins Today : "
           FUNCTION TRIM(WS-DISPLAY-CHECKINS)
           DISPLAY "  Check-outs Today: "
           FUNCTION TRIM(WS-DISPLAY-CHECKOUTS)
           DISPLAY " "
           DISPLAY "ROOM OCCUPANCY:"
           DISPLAY "  Occupied Rooms  : "
           FUNCTION TRIM(WS-DISPLAY-OCCUPIED)
           DISPLAY "  Total Rooms     : "
           FUNCTION TRIM(WS-DISPLAY-TOTAL)
           DISPLAY "  Occupancy Rate  : "
           FUNCTION TRIM(WS-DISPLAY-OCCUPANCY) "%"
           DISPLAY " "
           DISPLAY "REVENUE:"
           DISPLAY " Today's Revenue  : "
           FUNCTION TRIM(WS-DISPLAY-REVENUE)
           DISPLAY "=========================================="
           DISPLAY " ".

       END PROGRAM dailySummaryReport.
