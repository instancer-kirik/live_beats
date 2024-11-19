defmodule LiveBeats.TechTree.Examples do
  alias LiveBeats.TechTree
  alias LiveBeats.TechTree.{Item, Part, Kit, Documentation}

  def inventory_examples do
    # Create a new part with inventory tracking
    {:ok, microphone} = TechTree.create_part(%{
      name: "SM58 Microphone",
      description: "Professional dynamic microphone",
      part_number: "SM58-LC",
      category: "audio_equipment",
      manufacturer: "Shure",
      supplier: "Sweetwater",
      cost: Decimal.new("99.00"),
      quantity: 5,
      min_quantity: 2,
      location: "Storage Room B",
      specifications: %{
        "type" => "dynamic",
        "frequency_response" => "50 to 15,000 Hz",
        "impedance" => "300 ohms"
      }
    })

    # Check low inventory
    low_stock_parts = TechTree.list_parts(
      filters: [low_stock: true]
    )

    # Track part usage
    {:ok, updated_part} = TechTree.update_part(microphone, %{
      quantity: microphone.quantity - 1
    })

    # Get parts by supplier
    sweetwater_parts = TechTree.list_parts(
      filters: [supplier: "Sweetwater"]
    )
  end

  def equipment_examples do
    # Create new equipment item
    {:ok, mixer} = TechTree.create_item(%{
      name: "X32 Digital Mixer",
      description: "32-channel digital mixing console",
      category: "audio_mixer",
      status: "active",
      manufacturer: "Behringer",
      model: "X32",
      serial_number: "ABRX32001",
      purchase_date: ~D[2024-01-01],
      warranty_expiry: ~D[2026-01-01],
      specifications: %{
        "channels" => 32,
        "aux_sends" => 16,
        "effects" => ["reverb", "delay", "compression"]
      },
      maintenance_history: [
        %{
          "date" => "2024-01-01",
          "type" => "installation",
          "description" => "Initial setup and configuration"
        }
      ]
    })

    # Create maintenance record
    {:ok, updated_mixer} = TechTree.update_item(mixer, %{
      maintenance_history: [
        %{
          "date" => "2024-01-15",
          "type" => "calibration",
          "description" => "Annual calibration check"
        } | mixer.maintenance_history
      ]
    })
  end

  def kit_examples do
    # Create a microphone kit
    {:ok, mic_kit} = TechTree.create_kit(%{
      name: "Vocal Performance Kit",
      description: "Complete vocal microphone kit with accessories",
      kit_number: "VPK-001",
      category: "microphone_kit",
      status: "complete",
      location: "Storage Room A",
      contents: [
        %{"item_id" => 1, "quantity" => 1},  # SM58 Microphone
        %{"item_id" => 2, "quantity" => 1},  # Microphone Stand
        %{"item_id" => 3, "quantity" => 1}   # XLR Cable
      ],
      assembly_instructions: """
      1. Attach microphone to stand using the thread adapter
      2. Connect XLR cable to microphone
      3. Run cable to mixing console
      """,
      notes: "Check microphone windscreen before each use"
    })

    # Track kit usage
    {:ok, updated_kit} = TechTree.update_kit(mic_kit, %{
      status: "in_use"
    })
  end

  def shop_examples do
    # Create shop-specific equipment
    {:ok, shop_mixer} = TechTree.create_item(%{
      name: "X32 Digital Mixer",
      description: "32-channel digital mixing console",
      category: "audio_mixer",
      status: "active",
      manufacturer: "Behringer",
      model: "X32",
      serial_number: "ABRX32001",
      purchase_date: ~D[2024-01-01],
      warranty_expiry: ~D[2026-01-01],
      specifications: %{
        "channels" => 32,
        "aux_sends" => 16,
        "effects" => ["reverb", "delay", "compression"]
      },
      shop_id: 1  # Replace with actual shop ID
    })

    # Create shop-specific inventory
    {:ok, shop_mic} = TechTree.create_part(%{
      name: "SM58 Microphone",
      description: "Professional dynamic microphone",
      part_number: "SM58-LC",
      category: "audio_equipment",
      manufacturer: "Shure",
      supplier: "Sweetwater",
      cost: Decimal.new("99.00"),
      quantity: 5,
      min_quantity: 2,
      location: "Storage Room B",
      specifications: %{
        "type" => "dynamic",
        "frequency_response" => "50 to 15,000 Hz",
        "impedance" => "300 ohms"
      },
      shop_id: 1  # Replace with actual shop ID
    })

    # Create shop-specific kit
    {:ok, shop_kit} = TechTree.create_kit(%{
      name: "Live Performance Kit",
      description: "Complete live performance setup",
      kit_number: "LPK-001",
      category: "performance_kit",
      status: "complete",
      location: "Storage Room A",
      contents: [
        %{"item_id" => shop_mixer.id, "quantity" => 1},
        %{"item_id" => shop_mic.id, "quantity" => 4}
      ],
      assembly_instructions: """
      1. Set up mixer on sturdy table
      2. Connect power and test
      3. Set up microphones on stands
      4. Run sound check
      """,
      notes: "Requires at least 2 people for setup",
      shop_id: 1  # Replace with actual shop ID
    })

    # List all equipment for a shop
    shop_items = TechTree.list_shop_items(1)

    # Search shop-specific inventory
    search_results = TechTree.search_shop_parts(1, "microphone")

    # Check low stock items for a shop
    low_stock = TechTree.check_low_stock_parts(1)

    # Update inventory quantity
    {:ok, updated_part} = TechTree.update_shop_part_quantity(1, shop_mic.id, -1)

    # List all kits for a shop
    shop_kits = TechTree.list_shop_kits(1, 
      filters: [status: "complete"],
      sort: [desc: :name]
    )

    # Get shop-specific item
    shop_mixer = TechTree.get_shop_item!(1, shop_mixer.id)
  end

  def documentation_examples do
    # Create technical documentation
    {:ok, manual} = TechTree.create_documentation(%{
      title: "X32 Quick Setup Guide",
      description: "Basic setup instructions for X32 digital mixer",
      content: """
      # X32 Quick Setup Guide
      
      ## Initial Power Up
      1. Connect power cable
      2. Press power button
      3. Wait for system initialization
      
      ## Basic Configuration
      1. Set input gains
      2. Configure monitor mixes
      3. Set up effects
      """,
      doc_type: "guide",
      version: "1.0",
      author: "Technical Team",
      tags: ["mixer", "audio", "setup"],
      metadata: %{
        "equipment_model" => "X32",
        "difficulty_level" => "beginner",
        "estimated_time" => "30 minutes"
      }
    })
  end

  def search_examples do
    # Search for items
    items = TechTree.search_items("microphone", 
      filters: [category: "audio_equipment"]
    )

    # Search for parts with low inventory
    parts = TechTree.search_parts("cable", 
      filters: [low_stock: true]
    )

    # Search for kits
    kits = TechTree.search_kits("vocal", 
      filters: [status: "complete"]
    )

    # Search for documentation
    docs = TechTree.search_documentation("setup guide",
      filters: [doc_type: "guide"]
    )
  end
end
