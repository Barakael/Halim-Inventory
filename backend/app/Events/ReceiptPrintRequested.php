<?php

namespace App\Events;

use App\Models\ReceiptPrintJob;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ReceiptPrintRequested implements ShouldBroadcastNow
{
    use Dispatchable, SerializesModels;

    public function __construct(public ReceiptPrintJob $job) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('shop.'.$this->job->shop_id.'.receipts'),
        ];
    }

    public function broadcastAs(): string
    {
        return 'receipt.queued';
    }

    public function broadcastWith(): array
    {
        return [
            'job_id' => $this->job->id,
            'sale_id' => $this->job->sale_id,
            'serial_number' => $this->job->serial_number,
            'shop_id' => $this->job->shop_id,
        ];
    }
}
