import logging
from typing import Dict, Any, List
from django.db.models import Count
from jobs.models import SelectedJob

logger = logging.getLogger(__name__)

class ApplicationTrackerService:
    ALLOWED_TRANSITIONS = {
        SelectedJob.StatusChoices.SAVED: [SelectedJob.StatusChoices.SHORTLISTED, SelectedJob.StatusChoices.APPLIED, SelectedJob.StatusChoices.REJECTED],
        SelectedJob.StatusChoices.SHORTLISTED: [SelectedJob.StatusChoices.APPLIED, SelectedJob.StatusChoices.REJECTED],
        SelectedJob.StatusChoices.APPLIED: [SelectedJob.StatusChoices.INTERVIEWING, SelectedJob.StatusChoices.INTERVIEW_CALL_RECEIVED, SelectedJob.StatusChoices.REJECTED],
        SelectedJob.StatusChoices.INTERVIEWING: [SelectedJob.StatusChoices.OFFER_RECEIVED, SelectedJob.StatusChoices.REJECTED],
        SelectedJob.StatusChoices.INTERVIEW_CALL_RECEIVED: [SelectedJob.StatusChoices.INTERVIEWING, SelectedJob.StatusChoices.OFFER_RECEIVED, SelectedJob.StatusChoices.REJECTED],
        SelectedJob.StatusChoices.OFFER_RECEIVED: [SelectedJob.StatusChoices.REJECTED],
        SelectedJob.StatusChoices.REJECTED: [SelectedJob.StatusChoices.SAVED, SelectedJob.StatusChoices.APPLIED]
    }

    @classmethod
    def can_transition(cls, current_status: str, target_status: str) -> bool:
        if current_status == target_status:
            return True
        return target_status in cls.ALLOWED_TRANSITIONS.get(current_status, [])

    @classmethod
    def get_kanban_summary(cls, user) -> Dict[str, Any]:
        """Calculates counts per Kanban column for a user."""
        qs = SelectedJob.objects.filter(user=user).values('status').annotate(count=Count('id'))
        counts = {choice[0]: 0 for choice in SelectedJob.StatusChoices.choices}
        for item in qs:
            counts[item['status']] = item['count']
        return counts

    @classmethod
    def get_conversion_funnel(cls, user) -> Dict[str, Any]:
        """
        Returns conversion funnel statistics across stages:
        Saved -> Applied -> Interviewing -> Offer.
        """
        counts = cls.get_kanban_summary(user)
        saved = counts.get(SelectedJob.StatusChoices.SAVED, 0) + counts.get(SelectedJob.StatusChoices.SHORTLISTED, 0)
        applied = counts.get(SelectedJob.StatusChoices.APPLIED, 0)
        interviewing = counts.get(SelectedJob.StatusChoices.INTERVIEWING, 0) + counts.get(SelectedJob.StatusChoices.INTERVIEW_CALL_RECEIVED, 0)
        offer = counts.get(SelectedJob.StatusChoices.OFFER_RECEIVED, 0)
        rejected = counts.get(SelectedJob.StatusChoices.REJECTED, 0)

        total_active = saved + applied + interviewing + offer
        return {
            "stages": [
                {"stage": "Saved", "count": saved, "conversion_rate": 100.0 if saved > 0 else 0.0},
                {"stage": "Applied", "count": applied, "conversion_rate": round((applied / max(1, saved)) * 100, 1)},
                {"stage": "Interviewing", "count": interviewing, "conversion_rate": round((interviewing / max(1, applied)) * 100, 1)},
                {"stage": "Offer", "count": offer, "conversion_rate": round((offer / max(1, interviewing)) * 100, 1)},
                {"stage": "Rejected", "count": rejected, "conversion_rate": 0.0},
            ],
            "total_tracked": total_active + rejected,
            "overall_offer_rate": round((offer / max(1, applied)) * 100, 1) if applied > 0 else 0.0
        }
