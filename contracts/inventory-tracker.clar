;; Inventory Tracker Smart Contract
;; Module that keeps track of pantry items and expiration dates

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-ITEM-NOT-FOUND (err u404))
(define-constant ERR-INVALID-QUANTITY (err u400))
(define-constant ERR-ITEM-EXPIRED (err u405))
(define-constant ERR-INSUFFICIENT-STOCK (err u406))
(define-constant ERR-INVALID-DATE (err u407))

;; Data Variables
(define-data-var item-id-counter uint u0)
(define-data-var purchase-id-counter uint u0)
(define-data-var alert-id-counter uint u0)

;; Inventory items data structure
(define-map inventory-items
    { user: principal, item-id: uint }
    {
        item-name: (string-ascii 64),
        category: (string-ascii 32),
        brand: (string-ascii 64),
        current-quantity: uint,
        unit: (string-ascii 16),
        min-threshold: uint,
        max-capacity: uint,
        cost-per-unit: uint,
        location: (string-ascii 32),
        barcode: (string-ascii 32),
        created-at: uint,
        last-updated: uint
    }
)

;; Item batches for expiration tracking
(define-map item-batches
    { user: principal, item-id: uint, batch-id: uint }
    {
        batch-quantity: uint,
        purchase-date: uint,
        expiration-date: uint,
        supplier: (string-ascii 64),
        batch-number: (string-ascii 32),
        status: (string-ascii 16)
    }
)

;; Purchase history
(define-map purchase-history
    { user: principal, purchase-id: uint }
    {
        item-id: uint,
        quantity-purchased: uint,
        unit-price: uint,
        total-cost: uint,
        purchase-date: uint,
        store: (string-ascii 64),
        receipt-number: (string-ascii 32)
    }
)

;; Consumption tracking
(define-map consumption-log
    { user: principal, item-id: uint, date: uint }
    {
        quantity-used: uint,
        usage-type: (string-ascii 32),
        recipe-id: (optional uint),
        notes: (string-ascii 128)
    }
)

;; Low stock alerts
(define-map stock-alerts
    { user: principal, alert-id: uint }
    {
        item-id: uint,
        alert-type: (string-ascii 32),
        priority: uint,
        created-at: uint,
        acknowledged: bool,
        resolved: bool
    }
)

;; Shopping suggestions based on inventory
(define-map shopping-suggestions
    { user: principal, item-id: uint }
    {
        suggested-quantity: uint,
        reason: (string-ascii 128),
        priority-score: uint,
        suggested-at: uint,
        accepted: bool
    }
)

;; User inventory settings
(define-map inventory-settings
    { user: principal }
    {
        default-alert-days: uint,
        enable-expiry-alerts: bool,
        enable-low-stock-alerts: bool,
        preferred-units: (string-ascii 64),
        auto-reorder: bool,
        budget-limit: uint
    }
)

;; Private helper functions
(define-private (is-item-owner (item-id uint) (user principal))
    (is-some (map-get? inventory-items { user: user, item-id: item-id }))
)

(define-private (increment-item-counter)
    (let ((current-id (var-get item-id-counter)))
        (var-set item-id-counter (+ current-id u1))
        current-id
    )
)

(define-private (increment-purchase-counter)
    (let ((current-id (var-get purchase-id-counter)))
        (var-set purchase-id-counter (+ current-id u1))
        current-id
    )
)

(define-private (increment-alert-counter)
    (let ((current-id (var-get alert-id-counter)))
        (var-set alert-id-counter (+ current-id u1))
        current-id
    )
)

(define-private (is-quantity-valid (quantity uint))
    (> quantity u0)
)

(define-private (is-below-threshold (current-quantity uint) (min-threshold uint))
    (<= current-quantity min-threshold)
)

;; Public Functions

;; Add new item to inventory
(define-public (add-inventory-item
    (item-name (string-ascii 64))
    (category (string-ascii 32))
    (brand (string-ascii 64))
    (initial-quantity uint)
    (unit (string-ascii 16))
    (min-threshold uint)
    (max-capacity uint)
    (cost-per-unit uint)
    (location (string-ascii 32))
    (barcode (string-ascii 32))
)
    (let ((item-id (increment-item-counter)))
        (if (is-quantity-valid initial-quantity)
            (begin
                (map-set inventory-items
                    { user: tx-sender, item-id: item-id }
                    {
                        item-name: item-name,
                        category: category,
                        brand: brand,
                        current-quantity: initial-quantity,
                        unit: unit,
                        min-threshold: min-threshold,
                        max-capacity: max-capacity,
                        cost-per-unit: cost-per-unit,
                        location: location,
                        barcode: barcode,
                        created-at: stacks-block-height,
                        last-updated: stacks-block-height
                    }
                )
                (ok item-id)
            )
            ERR-INVALID-QUANTITY
        )
    )
)

;; Update item quantity
(define-public (update-item-quantity (item-id uint) (new-quantity uint))
    (match (map-get? inventory-items { user: tx-sender, item-id: item-id })
        item (if (is-quantity-valid new-quantity)
                (begin
                    (map-set inventory-items
                        { user: tx-sender, item-id: item-id }
                        (merge item { 
                            current-quantity: new-quantity,
                            last-updated: stacks-block-height 
                        })
                    )
                    ;; Check if low stock alert needed
                    (if (is-below-threshold new-quantity (get min-threshold item))
                        (create-stock-alert item-id "low-stock" u3)
                        (ok true)
                    )
                )
                ERR-INVALID-QUANTITY
            )
        ERR-ITEM-NOT-FOUND
    )
)

;; Add item batch with expiration date
(define-public (add-item-batch
    (item-id uint)
    (batch-id uint)
    (batch-quantity uint)
    (purchase-date uint)
    (expiration-date uint)
    (supplier (string-ascii 64))
    (batch-number (string-ascii 32))
)
    (if (is-item-owner item-id tx-sender)
        (if (and (is-quantity-valid batch-quantity) (> expiration-date purchase-date))
            (begin
                (map-set item-batches
                    { user: tx-sender, item-id: item-id, batch-id: batch-id }
                    {
                        batch-quantity: batch-quantity,
                        purchase-date: purchase-date,
                        expiration-date: expiration-date,
                        supplier: supplier,
                        batch-number: batch-number,
                        status: "active"
                    }
                )
                ;; Update total inventory quantity
                (match (map-get? inventory-items { user: tx-sender, item-id: item-id })
                    item (begin
                            (map-set inventory-items
                                { user: tx-sender, item-id: item-id }
                                (merge item { 
                                    current-quantity: (+ (get current-quantity item) batch-quantity),
                                    last-updated: stacks-block-height 
                                })
                            )
                            (ok true)
                        )
                    ERR-ITEM-NOT-FOUND
                )
            )
            ERR-INVALID-DATE
        )
        ERR-NOT-AUTHORIZED
    )
)

;; Record purchase
(define-public (record-purchase
    (item-id uint)
    (quantity-purchased uint)
    (unit-price uint)
    (store (string-ascii 64))
    (receipt-number (string-ascii 32))
)
    (let ((purchase-id (increment-purchase-counter)))
        (if (is-item-owner item-id tx-sender)
            (begin
                (map-set purchase-history
                    { user: tx-sender, purchase-id: purchase-id }
                    {
                        item-id: item-id,
                        quantity-purchased: quantity-purchased,
                        unit-price: unit-price,
                        total-cost: (* quantity-purchased unit-price),
                        purchase-date: stacks-block-height,
                        store: store,
                        receipt-number: receipt-number
                    }
                )
                (ok purchase-id)
            )
            ERR-NOT-AUTHORIZED
        )
    )
)

;; Record item consumption
(define-public (record-consumption
    (item-id uint)
    (quantity-used uint)
    (usage-type (string-ascii 32))
    (recipe-id (optional uint))
    (notes (string-ascii 128))
)
    (if (is-item-owner item-id tx-sender)
        (match (map-get? inventory-items { user: tx-sender, item-id: item-id })
            item (if (>= (get current-quantity item) quantity-used)
                    (begin
                        ;; Record consumption
                        (map-set consumption-log
                            { user: tx-sender, item-id: item-id, date: stacks-block-height }
                            {
                                quantity-used: quantity-used,
                                usage-type: usage-type,
                                recipe-id: recipe-id,
                                notes: notes
                            }
                        )
                        ;; Update inventory quantity
                        (map-set inventory-items
                            { user: tx-sender, item-id: item-id }
                            (merge item { 
                                current-quantity: (- (get current-quantity item) quantity-used),
                                last-updated: stacks-block-height 
                            })
                        )
                        (ok true)
                    )
                    ERR-INSUFFICIENT-STOCK
                )
            ERR-ITEM-NOT-FOUND
        )
        ERR-NOT-AUTHORIZED
    )
)

;; Create stock alert
(define-public (create-stock-alert
    (item-id uint)
    (alert-type (string-ascii 32))
    (priority uint)
)
    (let ((alert-id (increment-alert-counter)))
        (if (is-item-owner item-id tx-sender)
            (begin
                (map-set stock-alerts
                    { user: tx-sender, alert-id: alert-id }
                    {
                        item-id: item-id,
                        alert-type: alert-type,
                        priority: priority,
                        created-at: stacks-block-height,
                        acknowledged: false,
                        resolved: false
                    }
                )
                (ok alert-id)
            )
            ERR-NOT-AUTHORIZED
        )
    )
)

;; Acknowledge alert
(define-public (acknowledge-alert (alert-id uint))
    (match (map-get? stock-alerts { user: tx-sender, alert-id: alert-id })
        alert (begin
                (map-set stock-alerts
                    { user: tx-sender, alert-id: alert-id }
                    (merge alert { acknowledged: true })
                )
                (ok true)
            )
        ERR-ITEM-NOT-FOUND
    )
)

;; Set inventory preferences
(define-public (set-inventory-settings
    (default-alert-days uint)
    (enable-expiry-alerts bool)
    (enable-low-stock-alerts bool)
    (preferred-units (string-ascii 64))
    (auto-reorder bool)
    (budget-limit uint)
)
    (begin
        (map-set inventory-settings
            { user: tx-sender }
            {
                default-alert-days: default-alert-days,
                enable-expiry-alerts: enable-expiry-alerts,
                enable-low-stock-alerts: enable-low-stock-alerts,
                preferred-units: preferred-units,
                auto-reorder: auto-reorder,
                budget-limit: budget-limit
            }
        )
        (ok true)
    )
)

;; Generate shopping suggestion
(define-public (suggest-shopping-item
    (item-id uint)
    (suggested-quantity uint)
    (reason (string-ascii 128))
    (priority-score uint)
)
    (if (is-item-owner item-id tx-sender)
        (begin
            (map-set shopping-suggestions
                { user: tx-sender, item-id: item-id }
                {
                    suggested-quantity: suggested-quantity,
                    reason: reason,
                    priority-score: priority-score,
                    suggested-at: stacks-block-height,
                    accepted: false
                }
            )
            (ok true)
        )
        ERR-NOT-AUTHORIZED
    )
)

;; Accept shopping suggestion
(define-public (accept-shopping-suggestion (item-id uint))
    (match (map-get? shopping-suggestions { user: tx-sender, item-id: item-id })
        suggestion (begin
                    (map-set shopping-suggestions
                        { user: tx-sender, item-id: item-id }
                        (merge suggestion { accepted: true })
                    )
                    (ok true)
                )
        ERR-ITEM-NOT-FOUND
    )
)

;; Read-only functions

;; Get inventory item details
(define-read-only (get-inventory-item (user principal) (item-id uint))
    (map-get? inventory-items { user: user, item-id: item-id })
)

;; Get item batch details
(define-read-only (get-item-batch (user principal) (item-id uint) (batch-id uint))
    (map-get? item-batches { user: user, item-id: item-id, batch-id: batch-id })
)

;; Get purchase record
(define-read-only (get-purchase-record (user principal) (purchase-id uint))
    (map-get? purchase-history { user: user, purchase-id: purchase-id })
)

;; Get consumption log
(define-read-only (get-consumption-log (user principal) (item-id uint) (date uint))
    (map-get? consumption-log { user: user, item-id: item-id, date: date })
)

;; Get stock alert
(define-read-only (get-stock-alert (user principal) (alert-id uint))
    (map-get? stock-alerts { user: user, alert-id: alert-id })
)

;; Get shopping suggestion
(define-read-only (get-shopping-suggestion (user principal) (item-id uint))
    (map-get? shopping-suggestions { user: user, item-id: item-id })
)

;; Get inventory settings
(define-read-only (get-inventory-settings (user principal))
    (map-get? inventory-settings { user: user })
)

;; Get current counters
(define-read-only (get-item-counter)
    (var-get item-id-counter)
)

(define-read-only (get-purchase-counter)
    (var-get purchase-id-counter)
)

(define-read-only (get-alert-counter)
    (var-get alert-id-counter)
)