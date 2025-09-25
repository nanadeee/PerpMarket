;; Contract Name: PerpMarket
;; Simple Perpetual Futures Market (Clarity prototype)

;; Features:
;; - Price feed integration
;; - Collateral deposit support in STX
;; - Leveraged long/short positions
;; - PnL-based position settlement
;; - Liquidation mechanism for under-margined positions
;; - Priced feed with SCALE precision

(define-constant SCALE u1000000) ;; 1e6 fixed point
(define-constant MAINTENANCE-MARGIN-NUM u5) ;; 5%
(define-constant MAINTENANCE-MARGIN-DEN u100)
(define-constant PROTOCOL-FEE-NUM u5) ;; 0.5% fee numerator
(define-constant PROTOCOL-FEE-DEN u1000)
(define-constant LIQUIDATOR-REWARD-NUM u10) ;; 10%
(define-constant LIQUIDATOR-REWARD-DEN u100)

;; Error responses
(define-constant ERR-NOT-ADMIN (err u100))
(define-constant ERR-INVALID-LEVERAGE (err u102))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u103))
(define-constant ERR-POSITION-NOT-FOUND (err u104))
(define-constant ERR-NOT-OWNER (err u105))
(define-constant ERR-NOT-ACTIVE (err u106))
(define-constant ERR-TRANSFER-FAIL (err u107))
(define-constant ERR-NO-PRICE (err u108))
(define-constant ERR-NOTHING-TO-LIQUIDATE (err u109))
(define-constant ERR-ABOVE-MAINTENANCE (err u110))
(define-constant ERR-ZERO-PRICE (err u111))

;; admin and price data
(define-data-var admin (optional principal) none)
(define-data-var current-price uint u0)

;; position id counter
(define-data-var last-pos-id uint u0)

;; Position map: id => position data
(define-map positions 
  {id: uint} 
  {owner: principal, 
   side: bool, 
   collateral: uint,
   leverage: uint, 
   entry-price: uint, 
   notional: uint, 
   active: bool})

;; Read-only helpers
(define-read-only (get-admin)
  (var-get admin))

(define-read-only (get-current-price)
  (var-get current-price))

(define-read-only (get-position-by-id (id uint))
  (map-get? positions {id: id}))

;; Helper: Calculate PnL
(define-read-only (calculate-pnl (side bool) (notional uint) (entry uint) (price uint))
  (if side
      (/ (* notional (- price entry)) entry)
      (/ (* notional (- entry price)) entry)))

;; Helper: Calculate maintenance margin
(define-read-only (calculate-maintenance (notional uint))
  (/ (* notional MAINTENANCE-MARGIN-NUM) MAINTENANCE-MARGIN-DEN))

;; Helper: Calculate protocol fee
(define-read-only (calculate-fee (pnl uint))
  (/ (* pnl PROTOCOL-FEE-NUM) PROTOCOL-FEE-DEN))

;; Helper: Calculate liquidator reward
(define-read-only (calculate-reward (collateral uint))
  (/ (* collateral LIQUIDATOR-REWARD-NUM) LIQUIDATOR-REWARD-DEN))

;; Initialize admin (call once)
(define-public (initialize)
  (if (is-some (var-get admin))
      (err u200)
      (begin
        (var-set admin (some tx-sender))
        (ok true))))

;; Admin: Set current price
(define-public (set-price (price uint))
  (if (is-eq (some tx-sender) (var-get admin))
      (begin 
        (asserts! (> price u0) ERR-ZERO-PRICE)
        (var-set current-price price)
        (ok true))
      ERR-NOT-ADMIN))

;; Open new position
(define-public (open-position (side bool) (collateral uint) (leverage uint))
  (let ((price (get-current-price)))
    (asserts! (> collateral u0) ERR-INSUFFICIENT-COLLATERAL)
    (asserts! (> leverage u1) ERR-INVALID-LEVERAGE)
    (asserts! (> price u0) ERR-NO-PRICE)
    (let ((transfer-result (stx-transfer? collateral tx-sender (as-contract tx-sender))))
      (asserts! (is-ok transfer-result) ERR-TRANSFER-FAIL)
      (let ((notional (* collateral leverage)))
        (var-set last-pos-id (+ u1 (var-get last-pos-id)))
        (let ((position-id (var-get last-pos-id)))
          (map-set positions 
            {id: position-id} 
            {owner: tx-sender,
             side: side,
             collateral: collateral,
             leverage: leverage,
             entry-price: price,
             notional: notional,
             active: true})
          (ok position-id))))))

;; View position PnL
(define-read-only (view-position-pnl (id uint))
  (let ((price (get-current-price))
        (pos (get-position-by-id id)))
    (match pos 
           some-pos (if (not (get active some-pos))
                  ERR-NOT-ACTIVE
                  (if (> price u0)
                      (ok (calculate-pnl 
                            (get side some-pos)
                            (get notional some-pos)
                            (get entry-price some-pos)
                            price))
                      ERR-NO-PRICE))
           ERR-POSITION-NOT-FOUND)))

;; Close position
(define-public (close-position (position-id uint))
  (let ((price (get-current-price)))
    (asserts! (> price u0) ERR-NO-PRICE)
    (match (get-position-by-id position-id) 
           some-pos (begin
             (asserts! (get active some-pos) ERR-NOT-ACTIVE)
             (asserts! (is-eq tx-sender (get owner some-pos)) ERR-NOT-OWNER)
             (let ((pnl (calculate-pnl
                         (get side some-pos)
                         (get notional some-pos)
                         (get entry-price some-pos)
                         price))
                   (final-balance (+ (get collateral some-pos) pnl))
                   (position-key {id: position-id}))
               (map-delete positions position-key)
               (if (<= final-balance u0)
                   (ok u0)
                   (begin
                     (asserts! 
                       (is-ok (as-contract 
                               (stx-transfer? 
                                 final-balance 
                                 tx-sender 
                                 (get owner some-pos))))
                       ERR-TRANSFER-FAIL)
                     (ok final-balance)))))
           ERR-POSITION-NOT-FOUND)))

;; Liquidate position
(define-public (liquidate (position-id uint))
  (let ((price (get-current-price)))
    (asserts! (> price u0) ERR-NO-PRICE)
    (match (get-position-by-id position-id)
           some-pos (let ((maintenance (calculate-maintenance (get notional some-pos)))
                         (position-key {id: position-id}))
             (asserts! (< (get collateral some-pos) maintenance) ERR-NOTHING-TO-LIQUIDATE)
             (let ((pnl (calculate-pnl 
                         (get side some-pos)
                         (get notional some-pos)
                         (get entry-price some-pos)
                         price)))
               (asserts! (< (+ (get collateral some-pos) pnl) maintenance) ERR-ABOVE-MAINTENANCE)
               (let ((reward (calculate-reward (get collateral some-pos))))
                 (map-delete positions position-key)
                 (asserts!
                   (is-ok (as-contract 
                           (stx-transfer? 
                             reward 
                             tx-sender 
                             tx-sender)))
                   ERR-TRANSFER-FAIL)
                 (ok reward))))
           ERR-POSITION-NOT-FOUND)))