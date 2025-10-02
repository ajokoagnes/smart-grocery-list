;; Meal Planner Smart Contract
;; Module for suggesting recipes and creating shopping lists based on meal planning

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-RECIPE-NOT-FOUND (err u404))
(define-constant ERR-INVALID-RECIPE (err u400))
(define-constant ERR-MEAL-PLAN-EXISTS (err u409))
(define-constant ERR-MEAL-PLAN-NOT-FOUND (err u410))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))

;; Data Variables
(define-data-var recipe-id-counter uint u0)
(define-data-var meal-plan-id-counter uint u0)
(define-data-var shopping-list-id-counter uint u0)

;; Recipe data structure
(define-map recipes
    { recipe-id: uint }
    {
        name: (string-ascii 64),
        description: (string-ascii 256),
        prep-time: uint,
        cook-time: uint,
        servings: uint,
        difficulty: (string-ascii 16),
        cuisine-type: (string-ascii 32),
        calories-per-serving: uint,
        protein: uint,
        carbs: uint,
        fat: uint,
        created-by: principal,
        created-at: uint
    }
)

;; Recipe ingredients mapping
(define-map recipe-ingredients
    { recipe-id: uint, ingredient-index: uint }
    {
        ingredient-name: (string-ascii 64),
        quantity: uint,
        unit: (string-ascii 16),
        category: (string-ascii 32)
    }
)

;; User meal plans
(define-map meal-plans
    { user: principal, plan-id: uint }
    {
        plan-name: (string-ascii 64),
        start-date: uint,
        end-date: uint,
        total-recipes: uint,
        status: (string-ascii 16),
        created-at: uint
    }
)

;; Meal plan recipes (which recipes are scheduled when)
(define-map meal-plan-recipes
    { plan-id: uint, meal-date: uint, meal-type: (string-ascii 16) }
    {
        recipe-id: uint,
        servings-planned: uint,
        notes: (string-ascii 128)
    }
)

;; Generated shopping lists
(define-map shopping-lists
    { user: principal, list-id: uint }
    {
        plan-id: uint,
        list-name: (string-ascii 64),
        total-items: uint,
        estimated-cost: uint,
        generated-at: uint,
        status: (string-ascii 16)
    }
)

;; Shopping list items
(define-map shopping-list-items
    { list-id: uint, item-index: uint }
    {
        ingredient-name: (string-ascii 64),
        total-quantity: uint,
        unit: (string-ascii 16),
        category: (string-ascii 32),
        estimated-price: uint,
        priority: uint,
        purchased: bool
    }
)

;; User dietary preferences
(define-map user-preferences
    { user: principal }
    {
        dietary-restrictions: (string-ascii 128),
        preferred-cuisines: (string-ascii 128),
        cooking-skill: (string-ascii 16),
        household-size: uint,
        weekly-budget: uint,
        favorite-recipes: (list 10 uint)
    }
)

;; Private helper functions
(define-private (is-recipe-owner (recipe-id uint) (user principal))
    (match (map-get? recipes { recipe-id: recipe-id })
        recipe (is-eq (get created-by recipe) user)
        false
    )
)

(define-private (increment-recipe-counter)
    (let ((current-id (var-get recipe-id-counter)))
        (var-set recipe-id-counter (+ current-id u1))
        current-id
    )
)

(define-private (increment-meal-plan-counter)
    (let ((current-id (var-get meal-plan-id-counter)))
        (var-set meal-plan-id-counter (+ current-id u1))
        current-id
    )
)

(define-private (increment-shopping-list-counter)
    (let ((current-id (var-get shopping-list-id-counter)))
        (var-set shopping-list-id-counter (+ current-id u1))
        current-id
    )
)

(define-private (calculate-recipe-nutrition (servings uint) (base-calories uint) (base-protein uint) (base-carbs uint) (base-fat uint))
    {
        calories: (* base-calories servings),
        protein: (* base-protein servings),
        carbs: (* base-carbs servings),
        fat: (* base-fat servings)
    }
)

;; Public Functions

;; Create a new recipe
(define-public (create-recipe 
    (name (string-ascii 64))
    (description (string-ascii 256))
    (prep-time uint)
    (cook-time uint)
    (servings uint)
    (difficulty (string-ascii 16))
    (cuisine-type (string-ascii 32))
    (calories-per-serving uint)
    (protein uint)
    (carbs uint)
    (fat uint)
)
    (let ((recipe-id (increment-recipe-counter)))
        (map-set recipes
            { recipe-id: recipe-id }
            {
                name: name,
                description: description,
                prep-time: prep-time,
                cook-time: cook-time,
                servings: servings,
                difficulty: difficulty,
                cuisine-type: cuisine-type,
                calories-per-serving: calories-per-serving,
                protein: protein,
                carbs: carbs,
                fat: fat,
                created-by: tx-sender,
                created-at: stacks-block-height
            }
        )
        (ok recipe-id)
    )
)

;; Add ingredient to recipe
(define-public (add-recipe-ingredient
    (recipe-id uint)
    (ingredient-index uint)
    (ingredient-name (string-ascii 64))
    (quantity uint)
    (unit (string-ascii 16))
    (category (string-ascii 32))
)
    (if (is-recipe-owner recipe-id tx-sender)
        (begin
            (map-set recipe-ingredients
                { recipe-id: recipe-id, ingredient-index: ingredient-index }
                {
                    ingredient-name: ingredient-name,
                    quantity: quantity,
                    unit: unit,
                    category: category
                }
            )
            (ok true)
        )
        ERR-NOT-AUTHORIZED
    )
)

;; Create meal plan
(define-public (create-meal-plan
    (plan-name (string-ascii 64))
    (start-date uint)
    (end-date uint)
)
    (let ((plan-id (increment-meal-plan-counter)))
        (map-set meal-plans
            { user: tx-sender, plan-id: plan-id }
            {
                plan-name: plan-name,
                start-date: start-date,
                end-date: end-date,
                total-recipes: u0,
                status: "active",
                created-at: stacks-block-height
            }
        )
        (ok plan-id)
    )
)

;; Add recipe to meal plan
(define-public (schedule-meal
    (plan-id uint)
    (meal-date uint)
    (meal-type (string-ascii 16))
    (recipe-id uint)
    (servings-planned uint)
    (notes (string-ascii 128))
)
    (if (is-some (map-get? meal-plans { user: tx-sender, plan-id: plan-id }))
        (if (is-some (map-get? recipes { recipe-id: recipe-id }))
            (begin
                (map-set meal-plan-recipes
                    { plan-id: plan-id, meal-date: meal-date, meal-type: meal-type }
                    {
                        recipe-id: recipe-id,
                        servings-planned: servings-planned,
                        notes: notes
                    }
                )
                (ok true)
            )
            ERR-RECIPE-NOT-FOUND
        )
        ERR-MEAL-PLAN-NOT-FOUND
    )
)

;; Generate shopping list from meal plan
(define-public (generate-shopping-list
    (plan-id uint)
    (list-name (string-ascii 64))
)
    (let ((list-id (increment-shopping-list-counter)))
        (if (is-some (map-get? meal-plans { user: tx-sender, plan-id: plan-id }))
            (begin
                (map-set shopping-lists
                    { user: tx-sender, list-id: list-id }
                    {
                        plan-id: plan-id,
                        list-name: list-name,
                        total-items: u0,
                        estimated-cost: u0,
                        generated-at: stacks-block-height,
                        status: "pending"
                    }
                )
                (ok list-id)
            )
            ERR-MEAL-PLAN-NOT-FOUND
        )
    )
)

;; Add item to shopping list
(define-public (add-shopping-list-item
    (list-id uint)
    (item-index uint)
    (ingredient-name (string-ascii 64))
    (total-quantity uint)
    (unit (string-ascii 16))
    (category (string-ascii 32))
    (estimated-price uint)
    (priority uint)
)
    (if (is-some (map-get? shopping-lists { user: tx-sender, list-id: list-id }))
        (begin
            (map-set shopping-list-items
                { list-id: list-id, item-index: item-index }
                {
                    ingredient-name: ingredient-name,
                    total-quantity: total-quantity,
                    unit: unit,
                    category: category,
                    estimated-price: estimated-price,
                    priority: priority,
                    purchased: false
                }
            )
            (ok true)
        )
        ERR-NOT-AUTHORIZED
    )
)

;; Mark shopping list item as purchased
(define-public (mark-item-purchased (list-id uint) (item-index uint))
    (match (map-get? shopping-list-items { list-id: list-id, item-index: item-index })
        item (if (is-some (map-get? shopping-lists { user: tx-sender, list-id: list-id }))
                (begin
                    (map-set shopping-list-items
                        { list-id: list-id, item-index: item-index }
                        (merge item { purchased: true })
                    )
                    (ok true)
                )
                ERR-NOT-AUTHORIZED
            )
        ERR-RECIPE-NOT-FOUND
    )
)

;; Set user dietary preferences
(define-public (set-user-preferences
    (dietary-restrictions (string-ascii 128))
    (preferred-cuisines (string-ascii 128))
    (cooking-skill (string-ascii 16))
    (household-size uint)
    (weekly-budget uint)
    (favorite-recipes (list 10 uint))
)
    (begin
        (map-set user-preferences
            { user: tx-sender }
            {
                dietary-restrictions: dietary-restrictions,
                preferred-cuisines: preferred-cuisines,
                cooking-skill: cooking-skill,
                household-size: household-size,
                weekly-budget: weekly-budget,
                favorite-recipes: favorite-recipes
            }
        )
        (ok true)
    )
)

;; Read-only functions

;; Get recipe details
(define-read-only (get-recipe (recipe-id uint))
    (map-get? recipes { recipe-id: recipe-id })
)

;; Get recipe ingredient
(define-read-only (get-recipe-ingredient (recipe-id uint) (ingredient-index uint))
    (map-get? recipe-ingredients { recipe-id: recipe-id, ingredient-index: ingredient-index })
)

;; Get meal plan
(define-read-only (get-meal-plan (user principal) (plan-id uint))
    (map-get? meal-plans { user: user, plan-id: plan-id })
)

;; Get scheduled meal
(define-read-only (get-scheduled-meal (plan-id uint) (meal-date uint) (meal-type (string-ascii 16)))
    (map-get? meal-plan-recipes { plan-id: plan-id, meal-date: meal-date, meal-type: meal-type })
)

;; Get shopping list
(define-read-only (get-shopping-list (user principal) (list-id uint))
    (map-get? shopping-lists { user: user, list-id: list-id })
)

;; Get shopping list item
(define-read-only (get-shopping-list-item (list-id uint) (item-index uint))
    (map-get? shopping-list-items { list-id: list-id, item-index: item-index })
)

;; Get user preferences
(define-read-only (get-user-preferences (user principal))
    (map-get? user-preferences { user: user })
)

;; Get current counters
(define-read-only (get-recipe-counter)
    (var-get recipe-id-counter)
)

(define-read-only (get-meal-plan-counter)
    (var-get meal-plan-id-counter)
)

(define-read-only (get-shopping-list-counter)
    (var-get shopping-list-id-counter)
)

